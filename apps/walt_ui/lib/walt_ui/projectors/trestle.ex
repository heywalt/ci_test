defmodule WaltUi.Projectors.Trestle do
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
  alias WaltUi.Projections.Trestle

  project %Events.EnrichedWithTrestle{} = evt, _metadata, fn multi ->
    multi
    |> Ecto.Multi.one(:trestle, fn _ -> from t in Trestle, where: t.id == ^evt.id end)
    |> Ecto.Multi.insert_or_update(:upsert, &upsert_record(&1, evt))
  end

  project %Events.ProviderEnrichmentCompleted{provider_type: "trestle", status: "success"} = evt,
          _metadata,
          fn multi ->
            Logger.info("Provider data projection",
              event_id: evt.id,
              provider_type: "trestle",
              projection_status: "success",
              module: __MODULE__
            )

            multi
            |> Ecto.Multi.one(:trestle, fn _ -> from t in Trestle, where: t.id == ^evt.id end)
            |> Ecto.Multi.insert_or_update(:upsert, &upsert_provider_record(&1, evt))
          end

  project %Events.ProviderEnrichmentCompleted{}, _metadata, fn multi ->
    # Ignore non-trestle providers and error status events
    multi
  end

  project %EnrichmentReset{} = event, _metadata, fn multi ->
    Ecto.Multi.delete_all(multi, :delete_trestle, from(t in Trestle, where: t.id == ^event.id))
  end

  @impl Commanded.Event.Handler
  def error(error, event, _ctx) do
    Logger.error("Error projecting Trestle data",
      event_id: event.id,
      event_type: event.__struct__,
      module: __MODULE__,
      reason: inspect(error)
    )

    :skip
  end

  defp upsert_record(multi, event) do
    record = multi.trestle || %Trestle{}

    event
    |> Map.from_struct()
    |> filter_valid_addresses()
    |> then(&Trestle.changeset(record, &1))
  end

  defp upsert_provider_record(multi, event) do
    record = multi.trestle || %Trestle{}

    # Extract data from enrichment_data field and add id, phone, and quality_metadata
    enrichment_data =
      event.enrichment_data
      |> Map.put(:id, event.id)
      |> Map.put(:phone, event.phone)
      |> Map.put(:alternate_names, Map.get(event.enrichment_data, :alternate_names, []))
      |> Map.put(:quality_metadata, event.quality_metadata)
      |> filter_valid_addresses()

    Trestle.changeset(record, enrichment_data)
  end

  defp filter_valid_addresses(data) do
    case Map.get(data, :addresses) do
      addresses when is_list(addresses) ->
        valid_addresses =
          addresses
          |> Enum.filter(&valid_address?/1)
          |> Enum.reject(&po_box?/1)

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

  defp po_box?(%{street_1: street_1}) when is_binary(street_1) do
    street_1
    |> String.downcase()
    |> String.replace(".", "")
    |> String.starts_with?("po box")
  end

  defp po_box?(_address), do: false
end
