defmodule WaltUi.Handlers.Supervisor do
  @moduledoc false

  use Supervisor

  @handlers [
    WaltUi.Handlers.Search,
    WaltUi.Handlers.ProviderEnrichmentRequestedHandler,
    WaltUi.Handlers.EnrichmentCompositionRequestedHandler,
    WaltUi.Handlers.EmailSyncOnContactUpdate,
    WaltUi.Handlers.EmailSyncOnLeadCreated,
    WaltUi.Handlers.CalendarSyncOnLeadCreated,
    WaltUi.Handlers.CalendarSyncOnContactUpdate,
    WaltUi.Handlers.GeocodeOnAddressChange,
    WaltUi.Handlers.AutoTagReaOnLeadCreated
  ]

  def start_link(init_arg) do
    Supervisor.start_link(__MODULE__, init_arg,
      name: __MODULE__,
      max_restarts: Enum.count(@handlers) + 1
    )
  end

  def init(_init_arg) do
    children = Enum.filter(@handlers, &enabled?/1)
    Supervisor.init(children, strategy: :one_for_one)
  end

  defp enabled?(handler) do
    :walt_ui
    |> Application.get_env(handler, [])
    |> Keyword.get(:enabled?, true)
  end
end
