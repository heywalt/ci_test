defmodule WaltUi.Projectors.Faraday do
  @moduledoc false

  use Commanded.Projections.Ecto,
    application: CQRS,
    repo: Repo,
    name: __MODULE__,
    start_from: :current,
    consistency: :strong

  require Logger

  alias CQRS.Enrichments.Events
  alias CQRS.Enrichments.Events.EnrichmentReset
  alias WaltUi.Projections.Faraday

  project %Events.EnrichedWithFaraday{} = evt, _metadata, fn multi ->
    multi
    |> Ecto.Multi.one(:faraday, fn _ -> from f in Faraday, where: f.id == ^evt.id end)
    |> Ecto.Multi.insert_or_update(:upsert, &upsert_record(&1, evt))
  end

  project %Events.ProviderEnrichmentCompleted{provider_type: "faraday", status: "success"} = evt,
          _metadata,
          fn multi ->
            Logger.info("Provider data projection",
              event_id: evt.id,
              provider_type: "faraday",
              projection_status: "success",
              module: __MODULE__
            )

            multi
            |> Ecto.Multi.one(:faraday, fn _ -> from f in Faraday, where: f.id == ^evt.id end)
            |> Ecto.Multi.insert_or_update(:upsert, &upsert_provider_record(&1, evt))
          end

  project %Events.ProviderEnrichmentCompleted{}, _metadata, fn multi ->
    # Ignore non-faraday providers and error status events
    multi
  end

  project %EnrichmentReset{} = event, _metadata, fn multi ->
    Ecto.Multi.delete_all(multi, :delete_faraday, from(f in Faraday, where: f.id == ^event.id))
  end

  @impl Commanded.Event.Handler
  def error(error, event, _ctx) do
    Logger.error("Error projecting Faraday data",
      event_id: event.id,
      event_type: event.__struct__,
      module: __MODULE__,
      reason: inspect(error)
    )

    :skip
  end

  defp upsert_record(multi, event) do
    record = multi.faraday || %Faraday{}

    event
    |> Map.from_struct()
    |> then(&Faraday.changeset(record, &1))
  end

  defp upsert_provider_record(multi, event) do
    record = multi.faraday || %Faraday{}

    # Extract data from enrichment_data field and add id, phone, and quality_metadata
    enrichment_data =
      event.enrichment_data
      |> Map.put(:id, event.id)
      |> Map.put(:phone, event.phone)
      |> Map.put(:quality_metadata, event.quality_metadata)

    Faraday.changeset(record, enrichment_data)
  end
end
