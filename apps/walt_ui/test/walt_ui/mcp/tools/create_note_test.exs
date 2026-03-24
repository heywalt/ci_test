defmodule WaltUi.MCP.Tools.CreateNoteTest do
  use WaltUi.CqrsCase

  import WaltUi.Factory

  alias WaltUi.MCP.Tools.CreateNote

  describe "execute/2" do
    setup do
      user = insert(:user)
      contact = await_contact(user_id: user.id, email: "john.connor@skynet.com")

      [user: user, contact: contact]
    end

    test "creates a note for a valid contact", %{user: user, contact: contact} do
      frame = %{assigns: %{user_id: user.id}}
      params = %{"contact_id" => contact.id, "note" => "Met today. Things went well."}

      assert {:ok, %{"note" => note}} = CreateNote.execute(params, frame)

      assert note["content"] == "Met today. Things went well."
      assert note["contact_id"] == contact.id
      assert note["id"]
      assert note["created_at"]
    end

    test "returns error when user_id missing from frame", %{contact: contact} do
      frame = %{assigns: %{}}
      params = %{"contact_id" => contact.id, "note" => "Some note"}

      assert {:error, "user_id is required in context"} = CreateNote.execute(params, frame)
    end

    test "returns error when contact not found", %{user: user} do
      frame = %{assigns: %{user_id: user.id}}
      params = %{"contact_id" => Ecto.UUID.generate(), "note" => "Some note"}

      assert {:error, "Contact not found or not authorized"} = CreateNote.execute(params, frame)
    end

    test "returns error when contact belongs to different user", %{contact: contact} do
      other_user = insert(:user)
      frame = %{assigns: %{user_id: other_user.id}}
      params = %{"contact_id" => contact.id, "note" => "Some note"}

      assert {:error, "Contact not found or not authorized"} = CreateNote.execute(params, frame)
    end
  end
end
