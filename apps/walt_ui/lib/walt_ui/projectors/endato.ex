defmodule WaltUi.Projectors.Endato do
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
  alias WaltUi.Projections.Endato

  project %Events.EnrichedWithEndato{} = evt, _metadata, fn multi ->
    multi
    |> Ecto.Multi.one(:endato, fn _ -> from e in Endato, where: e.id == ^evt.id end)
    |> Ecto.Multi.insert_or_update(:upsert, &upsert_record(&1, evt))
  end

  project %Events.ProviderEnrichmentCompleted{provider_type: "endato", status: "success"} = evt,
          _metadata,
          fn multi ->
            Logger.info("Provider data projection",
              event_id: evt.id,
              provider_type: "endato",
              projection_status: "success",
              module: __MODULE__
            )

            multi
            |> Ecto.Multi.one(:endato, fn _ -> from e in Endato, where: e.id == ^evt.id end)
            |> Ecto.Multi.insert_or_update(:upsert, &upsert_provider_record(&1, evt))
          end

  project %Events.ProviderEnrichmentCompleted{}, _metadata, fn multi ->
    # Ignore non-endato providers and error status events
    multi
  end

  project %EnrichmentReset{} = event, _metadata, fn multi ->
    Ecto.Multi.delete_all(multi, :delete_endato, from(e in Endato, where: e.id == ^event.id))
  end

  @impl Commanded.Event.Handler
  def error(error, event, _ctx) do
    Logger.error("Error projecting Endato data",
      event_id: event.id,
      event_type: event.__struct__,
      module: __MODULE__,
      reason: inspect(error)
    )

    :skip
  end

  defp upsert_record(multi, event) do
    record = multi.endato || %Endato{}

    event
    |> Map.from_struct()
    |> filter_valid_addresses()
    |> then(&Endato.changeset(record, &1))
  end

  defp upsert_provider_record(multi, event) do
    record = multi.endato || %Endato{}

    # Extract data from enrichment_data field and add id, phone, and quality_metadata
    enrichment_data =
      event.enrichment_data
      |> Map.put(:id, event.id)
      |> Map.put(:phone, event.phone)
      |> Map.put(:quality_metadata, event.quality_metadata)
      |> filter_valid_addresses()

    Endato.changeset(record, enrichment_data)
  end

  defp filter_valid_addresses(data) do
    case Map.get(data, :addresses) do
      addresses when is_list(addresses) ->
        valid_addresses = Enum.filter(addresses, &valid_address?/1)
        Map.put(data, :addresses, valid_addresses)

      _ ->
        data
    end
  end

  defp valid_address?(address) do
    required_fields = [:street_1, :city, :state, :zip]

    Enum.all?(required_fields, fn field ->
      case Map.get(address, field) do
        val when is_binary(val) -> String.trim(val) != ""
        _ -> false
      end
    end)
  end
end
