defmodule WaltUi.Projectors.Jitter do
  @moduledoc false

  use Commanded.Projections.Ecto,
    application: CQRS,
    repo: Repo,
    name: __MODULE__,
    start_from: :current,
    consistency: :strong

  require Logger

  alias CQRS.Enrichments.Events.EnrichmentReset
  alias CQRS.Enrichments.Events.Jittered
  alias WaltUi.Projections.Jitter

  # Handle legacy Jittered events with nil IDs from bug fixed in 2025-09
  # These events were created when 262k+ aggregates initialized via EnrichedWithFaraday
  # had ptt scores but no state.id set. Skip gracefully to allow projection rebuilds.
  project %Jittered{id: nil} = evt, _metadata, fn multi ->
    Logger.warning("Skipping legacy Jittered event with nil ID",
      score: evt.score,
      timestamp: evt.timestamp
    )

    multi
  end

  project %Jittered{} = evt, _metadata, fn multi ->
    multi
    |> Ecto.Multi.one(:jitter, fn _ -> from j in Jitter, where: j.id == ^evt.id end)
    |> Ecto.Multi.insert_or_update(:upsert, &upsert_record(&1, evt))
  end

  project %EnrichmentReset{} = event, _metadata, fn multi ->
    Ecto.Multi.delete_all(multi, :delete_jitter, from(j in Jitter, where: j.id == ^event.id))
  end

  @impl Commanded.Event.Handler
  def error(error, event, _ctx) do
    Logger.error("Error projecting Jitter data",
      event_id: event.id,
      event_type: event.__struct__,
      module: __MODULE__,
      reason: inspect(error)
    )

    :skip
  end

  defp upsert_record(multi, event) do
    record = multi.jitter || %Jitter{}
    Jitter.changeset(record, %{id: event.id, ptt: event.score})
  end
end
