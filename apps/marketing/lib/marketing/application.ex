defmodule Marketing.Application do
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      MarketingWeb.Telemetry,
      {Phoenix.PubSub, name: Marketing.PubSub},
      MarketingWeb.Endpoint
    ]

    opts = [strategy: :one_for_one, name: Marketing.Supervisor]
    Supervisor.start_link(children, opts)
  end

  @impl true
  def config_change(changed, _new, removed) do
    MarketingWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
