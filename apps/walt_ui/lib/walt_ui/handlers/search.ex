defmodule WaltUi.Handlers.Search do
  @moduledoc false

  use Commanded.Event.Handler,
    application: CQRS,
    name: "search_handler"

  require Logger

  alias CQRS.Leads.Events

  def handle(%Events.LeadCreated{} = event, _metadata) do
    inserted_at = format_timestamp(event.timestamp)

    event
    |> Map.from_struct()
    |> Map.drop([:__meta__, :events, :notes, :unified_contact])
    |> Map.merge(%{
      collection_name: "contacts",
      inserted_at: inserted_at,
      updated_at: inserted_at,
      is_hidden: false
    })
    |> add_location_if_present()
    |> ExTypesense.index_document()
    |> case do
      {:ok, _} ->
        :ok

      {:error, error} ->
        Logger.warning("Error creating document in search handler",
          details: inspect(error),
          event_id: event.id
        )
    end
  end

  def handle(%Events.LeadUnified{} = event, _metadata) do
    updated_at = format_timestamp(event.timestamp)

    event
    |> Map.take([:city, :ptt, :state, :street_1, :street_2, :zip])
    |> Map.merge(%{id: event.id, collection_name: "contacts", updated_at: updated_at})
    |> ExTypesense.update_document()
    |> case do
      {:ok, _} ->
        :ok

      {:error, error} ->
        Logger.warning("Error updating document in search handler",
          details: inspect(error),
          event_id: event.id
        )
    end
  end

  def handle(%Events.LeadUpdated{} = event, _metadata) do
    updated_at = format_timestamp(event.timestamp)

    event.attrs
    |> Map.drop(["inserted_at", :inserted_at])
    |> normalize_for_typesense()
    |> Map.merge(%{id: event.id, collection_name: "contacts", updated_at: updated_at})
    |> add_location_if_present()
    |> ExTypesense.update_document()
    |> case do
      {:ok, _} ->
        :ok

      {:error, error} ->
        Logger.warning("Error updating document in search handler",
          details: inspect(error),
          event_id: event.id
        )
    end
  end

  def handle(%Events.LeadDeleted{} = event, _metadata) do
    ExTypesense.delete_document("contacts", event.id)

    :ok
  end

  defp normalize_for_typesense(attrs) do
    # Convert nil ptt to 0 for TypeSense compatibility, but only if key is present
    case CQRS.Utils.get(attrs, :ptt, :not_present) do
      # Key present with nil value, convert to 0
      nil -> Map.put(attrs, :ptt, 0)
      # Key not present or has a value, keep as is
      _ -> attrs
    end
  end

  defp add_location_if_present(data) do
    latitude = get_field_value(data, :latitude)
    longitude = get_field_value(data, :longitude)

    case {latitude, longitude} do
      {%Decimal{} = lat, %Decimal{} = lng} ->
        lat_float = Decimal.to_float(lat)
        lng_float = Decimal.to_float(lng)
        Map.put(data, :location, [lat_float, lng_float])

      {lat, lng} when is_binary(lat) and is_binary(lng) ->
        case {Float.parse(lat), Float.parse(lng)} do
          {{lat_float, ""}, {lng_float, ""}} ->
            Map.put(data, :location, [lat_float, lng_float])

          _ ->
            data
        end

      _ ->
        data
    end
  end

  defp get_field_value(data, key) do
    Map.get(data, key) || Map.get(data, to_string(key))
  end

  defp format_timestamp(timestamp) when is_binary(timestamp) do
    {:ok, naive_datetime} = NaiveDateTime.from_iso8601(timestamp)
    format_timestamp(naive_datetime)
  end

  defp format_timestamp(%NaiveDateTime{} = timestamp) do
    timestamp
    |> DateTime.from_naive!("Etc/UTC")
    |> DateTime.to_unix()
  end
end
