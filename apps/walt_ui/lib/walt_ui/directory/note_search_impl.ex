defmodule WaltUi.Directory.NoteSearchImpl do
  @moduledoc false

  defimpl Jason.Encoder, for: WaltUi.Directory.Note do
    def encode(note, opts) do
      contact = WaltUi.Contacts.get_contact(note.contact_id)

      note
      |> Map.take([:id, :note, :contact_id])
      |> Map.merge(%{user_id: contact.user_id})
      |> Jason.Encode.map(opts)
    end
  end
end
