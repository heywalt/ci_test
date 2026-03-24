defmodule WaltUi.Skyslope.File do
  @moduledoc false

  use TypedStruct
  import Ecto.Changeset
  require Logger

  alias WaltUi.Contacts
  alias WaltUi.Projections.Contact

  typedstruct do
    field :city, String.t()
    field :contacts, [Contact.t() | map], default: []
    field :id, integer, enforce: true
    field :mls_number, String.t()
    field :name, String.t(), enforce: true
    field :state, String.t()
    field :street_1, String.t()
    field :street_2, String.t()
    field :type, String.t(), enforce: true
    field :zip, String.t()
  end

  @spec from_http(map, Ecto.UUID.t()) :: t | nil
  def from_http(http, user_id) do
    attrs = http_to_attrs(http, user_id)

    types = %{
      city: :string,
      contacts: {:array, :map},
      id: :integer,
      mls_number: :string,
      name: :string,
      state: :string,
      street_1: :string,
      street_2: :string,
      type: :string,
      zip: :string
    }

    {struct(__MODULE__), types}
    |> cast(attrs, Map.keys(types))
    |> validate_required([:id, :name, :type])
    |> case do
      %{valid?: true} ->
        struct(__MODULE__, attrs)

      changeset ->
        Logger.warning("Skyslope file cannot be parsed",
          details: inspect(changeset),
          reason: inspect(changeset.errors)
        )

        nil
    end
  end

  defp http_to_attrs(http, user_id) do
    %{
      city: get_in(http, ["property", "city"]),
      contacts: find_contacts(http, user_id),
      id: http["id"],
      mls_number: http["mlsNumber"],
      name: http["name"],
      state: get_in(http, ["property", "state"]),
      street_1:
        get_in(http, ["property", "streetNumber"]) <>
          " " <> get_in(http, ["property", "streetName"]),
      street_2: get_in(http, ["property", "unitNumber"]),
      type: http["representationType"],
      zip: get_in(http, ["property", "postalCode"])
    }
  end

  defp find_contacts(%{"contacts" => []}, _user_id), do: []

  defp find_contacts(%{"contacts" => contacts}, user_id) when is_list(contacts) do
    {walt_contacts, skyslope_contacts} =
      contacts
      |> Enum.flat_map(&maybe_get_contact_id(user_id, &1))
      |> Enum.split_with(fn data -> is_binary(data) end)

    walt_contacts
    |> Contacts.get_contacts_in_id_list(preload: [])
    |> Enum.concat(skyslope_contacts)
    |> Enum.reject(&is_nil/1)
  end

  defp find_contacts(_http, _user_id), do: []

  defp maybe_get_contact_id(user_id, data) do
    case Contacts.get_by_email(user_id, data["email"]) do
      [] ->
        [
          %{
            city: get_in(data, ["primaryAddress", "city"]),
            first_name: data["firstName"],
            last_name: data["lastName"],
            state: get_in(data, ["primaryAddress", "state"])
          }
        ]

      contacts ->
        contacts
    end
  end
end
