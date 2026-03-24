defmodule WaltUi.Directory do
  @moduledoc """
  The Directory context.
  """
  import Ecto.Query, warn: false

  alias WaltUi.Directory.Note

  def house_number_and_street(contact) do
    String.trim("#{contact.street_1} #{contact.street_2}")
  end

  def city_state_zip(contact) do
    [contact.city, contact.state, contact.zip]
    |> Enum.reject(fn x -> is_nil(x) or String.trim(x) == "" end)
    |> Enum.join(", ")
  end

  ###############################
  # NOTES
  ###############################
  def fetch_note(id) do
    case Repo.get!(Note, id) do
      nil ->
        {:error, :not_found}

      note ->
        {:ok, note}
    end
  end

  def create_note(attrs \\ %{}) do
    %Note{}
    |> Note.changeset(attrs)
    |> Repo.insert()
  end

  def create_note!(attrs \\ %{}) do
    %Note{}
    |> Note.changeset(attrs)
    |> Repo.insert!()
  end

  def update_note(%Note{} = note, attrs) do
    note
    |> Note.changeset(attrs)
    |> Repo.update()
  end

  def delete_note(%Note{} = note) do
    Repo.delete(note)
  end

  ###############################
  # CONTACT NOTES
  ###############################
  def list_contacts_notes(contact_id) do
    query = from(notes in Note, where: notes.contact_id == ^contact_id)

    Repo.all(query)
  end

  def list_users_contacts_notes(user_id) do
    query =
      from(notes in Note,
        join: contacts in assoc(notes, :contact),
        where: contacts.user_id == ^user_id
      )

    Repo.all(query)
  end

  @doc """
  Search notes by content for a given user.
  Returns notes with their associated contacts preloaded.
  """
  def search_notes(user_id, search_term, opts \\ []) do
    limit = Keyword.get(opts, :limit, 10)
    pattern = "%#{search_term}%"

    from(n in Note,
      join: c in assoc(n, :contact),
      where: c.user_id == ^user_id,
      where: ilike(n.note, ^pattern),
      order_by: [desc: n.inserted_at],
      limit: ^limit,
      preload: [contact: c]
    )
    |> Repo.all()
  end
end
