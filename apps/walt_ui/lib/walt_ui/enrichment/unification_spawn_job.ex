defmodule WaltUi.Enrichment.UnificationSpawnJob do
  @moduledoc """
  This job is started by the `UnificationCronJob` to attempt
  enrichment and unification for a given set of user contact IDs.
  """
  use Oban.Worker, max_attempts: 3, queue: :enrichment

  @impl true
  def perform(%{args: %{"ids" => ids}}) do
    Enum.each(ids, fn id ->
      DynamicSupervisor.start_child(
        WaltUi.Enrichment.UnificationSupervisor,
        {WaltUi.Enrichment.UnificationFsm, {id, []}}
      )
    end)
  end
end
