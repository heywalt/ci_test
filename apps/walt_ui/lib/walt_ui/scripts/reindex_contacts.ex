defmodule WaltUi.Scripts.ReindexContacts do
  @moduledoc false

  def run(collection_name \\ "contacts") do
    stream =
      WaltUi.Projections.Contact
      |> Repo.stream()
      |> Stream.map(&format_contact/1)

    Repo.transaction(
      fn ->
        stream
        |> Enum.to_list()
        |> then(&ExTypesense.import_documents(collection_name, &1, batch_size: 100))
      end,
      timeout: :infinity
    )
  end

  def contact_schema(collection_name) do
    %{
      name: collection_name,
      fields: [
        %{
          facet: true,
          index: true,
          infix: false,
          locale: "",
          name: "first_name",
          optional: true,
          sort: true,
          stem: false,
          store: true,
          type: "string"
        },
        %{
          facet: true,
          index: true,
          infix: false,
          locale: "",
          name: "last_name",
          optional: true,
          sort: true,
          stem: false,
          store: true,
          type: "string"
        },
        %{
          facet: true,
          index: true,
          infix: false,
          locale: "",
          name: "email",
          optional: true,
          sort: false,
          stem: false,
          store: true,
          type: "string"
        },
        %{
          facet: false,
          index: true,
          infix: false,
          locale: "",
          name: "ptt",
          optional: false,
          sort: true,
          stem: false,
          store: true,
          type: "int32"
        },
        %{
          facet: false,
          index: true,
          infix: false,
          locale: "",
          name: "user_id",
          optional: false,
          sort: false,
          stem: false,
          store: true,
          type: "string"
        },
        %{
          facet: true,
          index: true,
          infix: false,
          locale: "",
          name: "inserted_at",
          optional: false,
          sort: true,
          stem: false,
          store: true,
          type: "int64"
        },
        %{
          facet: true,
          index: true,
          infix: false,
          locale: "",
          name: "updated_at",
          optional: false,
          sort: true,
          stem: false,
          store: true,
          type: "int64"
        },
        %{
          facet: true,
          index: true,
          infix: false,
          locale: "",
          name: "city",
          optional: true,
          sort: true,
          stem: false,
          store: true,
          type: "string"
        },
        %{
          facet: true,
          index: true,
          infix: false,
          locale: "",
          name: "state",
          optional: true,
          sort: true,
          stem: false,
          store: true,
          type: "string"
        },
        %{
          facet: true,
          index: true,
          infix: false,
          locale: "",
          name: "zip",
          optional: true,
          sort: true,
          stem: false,
          store: true,
          type: "string"
        },
        %{
          facet: true,
          index: true,
          infix: false,
          locale: "",
          name: "tags",
          optional: true,
          sort: false,
          stem: false,
          store: true,
          type: "string[]"
        },
        %{
          facet: false,
          index: true,
          infix: false,
          locale: "",
          name: "location",
          optional: true,
          sort: true,
          stem: false,
          store: true,
          type: "geopoint"
        },
        %{
          facet: true,
          index: true,
          infix: false,
          locale: "",
          name: "is_hidden",
          optional: true,
          sort: false,
          stem: false,
          store: true,
          type: "bool"
        }
      ],
      default_sorting_field: "ptt",
      enable_nested_fields: true
    }
  end

  defp format_contact(contact) do
    inserted_at = format_timestamp(contact.inserted_at)
    updated_at = format_timestamp(contact.updated_at)

    contact
    |> Map.from_struct()
    |> Map.drop([:__meta__, :inserted_at, :updated_at, :unified_contact, :notes, :events])
    |> Map.merge(%{inserted_at: inserted_at, updated_at: updated_at})
    |> add_location_if_present()
  end

  defp add_location_if_present(contact_data) do
    case {contact_data[:latitude], contact_data[:longitude]} do
      {%Decimal{} = lat, %Decimal{} = lng} ->
        lat_float = Decimal.to_float(lat)
        lng_float = Decimal.to_float(lng)
        Map.put(contact_data, :location, [lat_float, lng_float])

      _ ->
        contact_data
    end
  end

  defp format_timestamp(timestamp) do
    timestamp
    |> DateTime.from_naive!("Etc/UTC")
    |> DateTime.to_unix()
  end
end
