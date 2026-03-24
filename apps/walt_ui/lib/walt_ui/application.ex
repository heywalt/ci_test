defmodule WaltUi.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  alias Appsignal.Logger.Handler, as: AppsignalHandler
  alias Appsignal.Phoenix.LiveView, as: AppsignalLiveView

  @impl true
  def start(_type, _args) do
    AppsignalHandler.add("walt_ui")
    AppsignalLiveView.attach()

    children = [
      goth(),
      {Cluster.Supervisor,
       [Application.get_env(:libcluster, :topologies), [name: WaltUi.ClusterSupervisor]]},
      WaltUiWeb.Telemetry,
      {Phoenix.PubSub, name: WaltUi.PubSub},

      # CQRS Leadership System - optional based on config
      cqrs_leader(),
      # Supervisor for CQRS processes (managed by CQRSLeader or runs directly)
      WaltUi.CQRSSupervisor,
      {Task.Supervisor, name: WaltUi.TaskSupervisor},
      {Finch, name: WaltUi.Finch},
      WaltUiWeb.Endpoint,
      WaltUi.Enrichment.Supervisor,
      WaltUi.Providers.Supervisor,
      WaltUi.Calendars.Supervisor,
      {WaltUi.Contacts.CreateContactsConsumer, []},
      {WaltUi.Contacts.UpsertContactsConsumer, []},
      {Oban, Application.fetch_env!(:walt_ui, Oban)}
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: WaltUi.Supervisor]

    children
    |> Enum.filter(& &1)
    |> Supervisor.start_link(opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    WaltUiWeb.Endpoint.config_change(changed, removed)
    :ok
  end

  defp cqrs_leader do
    if Application.get_env(:walt_ui, :cqrs_leader_enabled, true) do
      WaltUi.CQRSLeader
    end
  end

  defp goth do
    if Application.get_env(:walt_ui, :goth_enabled?, true) do
      creds =
        :walt_ui
        |> Application.get_env(:google, [])
        |> Keyword.get(:service_account_credentials_json)
        |> Jason.decode!()

      {Goth, name: WaltUi.Goth, source: {:service_account, creds}, refresh_before: 3_000}
    end
  end
end
