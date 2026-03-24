defmodule WaltUi.MCP.Tools.SearchNotesTest do
  use WaltUi.CqrsCase

  import WaltUi.Factory

  alias WaltUi.Directory
  alias WaltUi.MCP.Tools.SearchNotes

  describe "execute/2" do
    setup do
      user = insert(:user)
      contact = await_contact(user_id: user.id, first_name: "John", last_name: "Connor")

      [user: user, contact: contact]
    end

    test "finds notes matching search query", %{user: user, contact: contact} do
      {:ok, _note} =
        Directory.create_note(%{
          contact_id: contact.id,
          note: "Loves basketball and Lakers games"
        })

      frame = %{assigns: %{user_id: user.id}}
      params = %{"query" => "basketball"}

      assert {:ok, %{"results" => results}} = SearchNotes.execute(params, frame)
      assert length(results) == 1

      [result] = results
      assert result["note"]["content"] =~ "basketball"
      assert result["contact"]["id"] == contact.id
      assert result["contact"]["name"] == "John Connor"
    end

    test "returns empty results when no matches", %{user: user, contact: contact} do
      {:ok, _note} = Directory.create_note(%{contact_id: contact.id, note: "Loves soccer"})

      frame = %{assigns: %{user_id: user.id}}
      params = %{"query" => "basketball"}

      assert {:ok, %{"results" => []}} = SearchNotes.execute(params, frame)
    end

    test "respects limit parameter", %{user: user, contact: contact} do
      for i <- 1..5 do
        {:ok, _note} =
          Directory.create_note(%{contact_id: contact.id, note: "Note about basketball #{i}"})
      end

      frame = %{assigns: %{user_id: user.id}}
      params = %{"query" => "basketball", "limit" => 3}

      assert {:ok, %{"results" => results}} = SearchNotes.execute(params, frame)
      assert length(results) == 3
    end

    test "only returns notes for user's contacts", %{user: user, contact: contact} do
      other_user = insert(:user)
      other_contact = await_contact(user_id: other_user.id, first_name: "Sarah")

      {:ok, _my_note} = Directory.create_note(%{contact_id: contact.id, note: "Likes basketball"})

      {:ok, _other_note} =
        Directory.create_note(%{contact_id: other_contact.id, note: "Also likes basketball"})

      frame = %{assigns: %{user_id: user.id}}
      params = %{"query" => "basketball"}

      assert {:ok, %{"results" => results}} = SearchNotes.execute(params, frame)
      assert length(results) == 1
      assert List.first(results)["contact"]["id"] == contact.id
    end

    test "returns error when user_id missing from frame" do
      frame = %{assigns: %{}}
      params = %{"query" => "basketball"}

      assert {:error, "user_id is required in context"} = SearchNotes.execute(params, frame)
    end

    test "search is case insensitive", %{user: user, contact: contact} do
      {:ok, _note} = Directory.create_note(%{contact_id: contact.id, note: "Loves BASKETBALL"})

      frame = %{assigns: %{user_id: user.id}}
      params = %{"query" => "basketball"}

      assert {:ok, %{"results" => results}} = SearchNotes.execute(params, frame)
      assert length(results) == 1
    end
  end
end
