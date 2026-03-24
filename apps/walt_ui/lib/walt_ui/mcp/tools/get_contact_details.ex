defmodule WaltUi.MCP.Tools.GetContactDetails do
  @moduledoc """
  Get detailed information about a specific contact.
  Returns all available data including notes and enrichment.
  """

  use Anubis.Server.Component, type: :tool

  import Ecto.Query

  alias Repo
  alias WaltUi.Projections.Contact
  alias WaltUi.Projections.Enrichment

  schema do
    field :contact_id, :string, required: true, description: "The ID of the contact to retrieve"
  end

  @impl true
  def execute(params, frame) do
    user_id = frame.assigns[:user_id]
    contact_id = Map.get(params, "contact_id")

    cond do
      is_nil(user_id) ->
        {:error, "user_id is required in context"}

      is_nil(contact_id) ->
        {:error, "contact_id is required"}

      true ->
        case get_contact_details(user_id, contact_id) do
          nil ->
            {:error, "Contact not found or access denied"}

          contact ->
            {:ok, format_full_contact(contact)}
        end
    end
  end

  defp get_contact_details(user_id, contact_id) do
    from(c in Contact,
      where: c.id == ^contact_id and c.user_id == ^user_id,
      preload: [:notes, :tags]
    )
    |> Repo.one()
  end

  defp format_full_contact(contact) do
    enrichment = get_enrichment(contact.enrichment_id)

    %{
      "id" => contact.id,
      "name" => format_name(contact),
      "first_name" => contact.first_name,
      "last_name" => contact.last_name,
      "email" => contact.email,
      "phone" => contact.phone,
      "address" => %{
        "street_1" => contact.street_1,
        "street_2" => contact.street_2,
        "city" => contact.city,
        "state" => contact.state,
        "zip" => contact.zip,
        "latitude" => contact.latitude,
        "longitude" => contact.longitude
      },
      "ptt" => contact.ptt,
      "is_favorite" => contact.is_favorite,
      "anniversary" => contact.anniversary,
      "birthday" => contact.birthday,
      "date_of_home_purchase" => contact.date_of_home_purchase,
      "notes" => format_notes(contact.notes),
      "tags" => Enum.map(contact.tags, & &1.name),
      "enrichment" => format_full_enrichment(enrichment),
      "created_at" => contact.inserted_at,
      "updated_at" => contact.updated_at
    }
  end

  defp get_enrichment(nil), do: nil

  defp get_enrichment(enrichment_id) do
    Repo.get(Enrichment, enrichment_id)
  end

  defp format_notes(notes) do
    notes
    |> Enum.sort_by(& &1.inserted_at, {:desc, DateTime})
    |> Enum.map(fn note ->
      %{
        "content" => note.note,
        "created_at" => note.inserted_at
      }
    end)
  end

  defp format_full_enrichment(nil), do: %{}

  defp format_full_enrichment(enrichment) do
    Map.from_struct(enrichment)
    |> Map.drop([:__meta__, :id, :inserted_at, :updated_at])
  end

  defp format_name(contact) do
    [contact.first_name, contact.last_name]
    |> Enum.reject(&is_nil/1)
    |> Enum.join(" ")
    |> String.trim()
  end
end
