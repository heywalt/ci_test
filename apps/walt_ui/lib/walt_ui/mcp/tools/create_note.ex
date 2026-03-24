defmodule WaltUi.MCP.Tools.CreateNote do
  @moduledoc """
  Create a note for a contact.
  """

  use Anubis.Server.Component, type: :tool

  require Logger

  alias WaltUi.Directory
  alias WaltUi.Projections.Contact

  schema do
    field :contact_id, :string, required: true, description: "UUID of the contact"
    field :note, :string, required: true, description: "The note content"
  end

  @impl true
  def execute(params, frame) do
    user_id = frame.assigns[:user_id]
    contact_id = Map.get(params, "contact_id")
    note_content = Map.get(params, "note")

    Logger.info("CreateNote called for contact: #{contact_id}")

    with :ok <- validate_user_id(user_id),
         :ok <- validate_contact_ownership(contact_id, user_id),
         {:ok, note} <- Directory.create_note(%{contact_id: contact_id, note: note_content}) do
      Logger.info("CreateNote created note: #{note.id}")

      {:ok,
       %{
         "note" => %{
           "id" => note.id,
           "content" => note.note,
           "contact_id" => note.contact_id,
           "created_at" => NaiveDateTime.to_iso8601(note.inserted_at)
         }
       }}
    end
  end

  defp validate_user_id(nil), do: {:error, "user_id is required in context"}
  defp validate_user_id(_user_id), do: :ok

  defp validate_contact_ownership(contact_id, user_id) do
    case Repo.get_by(Contact, id: contact_id, user_id: user_id) do
      nil -> {:error, "Contact not found or not authorized"}
      _contact -> :ok
    end
  end
end
