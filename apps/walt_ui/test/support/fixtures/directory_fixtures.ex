defmodule WaltUi.DirectoryFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `WaltUi.Directory` context.
  """

  import WaltUi.Factory

  @doc """
  Generate a note.
  """
  def note_fixture(attrs \\ %{}) do
    contact = insert(:contact)

    {:ok, note} =
      attrs
      |> Enum.into(%{
        contact_id: contact.id,
        note: "This is a great note"
      })
      |> WaltUi.Directory.create_note()

    note
  end
end
