defmodule WaltUi.ProcessManagers.Supervisor do
  @moduledoc false

  use Supervisor

  @process_managers [
    WaltUi.ProcessManagers.CalendarMeetingsManager,
    WaltUi.ProcessManagers.ContactEnrichmentManager,
    WaltUi.ProcessManagers.EnrichmentOrchestrationManager,
    WaltUi.ProcessManagers.EnrichmentResetManager,
    WaltUi.ProcessManagers.UnificationManager
  ]

  def start_link(_arg) do
    Supervisor.start_link(__MODULE__, [],
      name: __MODULE__,
      max_restarts: Enum.count(@process_managers) + 1
    )
  end

  def init(_arg) do
    children = Enum.filter(@process_managers, &enabled?/1)
    Supervisor.init(children, strategy: :one_for_one)
  end

  defp enabled?(process_manager) do
    :walt_ui
    |> Application.get_env(process_manager, [])
    |> Keyword.get(:enabled?, true)
  end
end
