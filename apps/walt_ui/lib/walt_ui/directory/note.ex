defmodule WaltUi.Directory.Note do
  @moduledoc """
  The schema for notes. Notes are used to store information about a contact.
  """
  use Repo.WaltSchema

  import Ecto.Changeset

  ##########################
  # For search via Typesense
  ##########################
  @behaviour ExTypesense
  @impl ExTypesense
  def get_field_types do
    %{
      fields: [
        %{name: "id", type: "string"},
        %{name: "note", type: "string"},
        %{name: "contact_id", type: "string"},
        %{name: "user_id", type: "string"}
      ]
    }
  end

  schema "notes" do
    field :note, :string

    belongs_to :contact, WaltUi.Projections.Contact

    timestamps()
  end

  @doc false
  def changeset(contact, attrs) do
    contact
    |> cast(attrs, [:id, :note, :contact_id])
    |> validate_required([:note, :contact_id])
  end

  def after_insert(note, _args) do
    ExTypesense.index_document("notes", note)
    note
  end

  def after_update(note, _args) do
    ExTypesense.update_document(note, note.id)
    note
  end

  def after_delete(note, _args) do
    ExTypesense.delete_document(note, note.id)
    note
  end
end
