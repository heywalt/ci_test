defmodule WaltUiWeb.Api.Controllers.NotesControllerTest do
  use WaltUiWeb.ConnCase

  import WaltUi.DirectoryFixtures
  import WaltUi.AccountFixtures

  alias WaltUi.Account
  alias WaltUi.Contacts

  @update_attrs %{
    note: "this is an updated note"
  }

  setup %{conn: conn} do
    {:ok, conn: put_req_header(conn, "accept", "application/json")}
  end

  describe "notes index" do
    test "lists all notes for a user", %{conn: conn} do
      user = user_fixture()

      conn =
        conn
        |> authenticate_user(user)
        |> get(~p"/api/notes")

      assert json_response(conn, 200)["data"] == []
    end

    test "fails when unauthorized", %{conn: conn} do
      conn = get(conn, ~p"/api/notes")

      assert json_response(conn, 401)["data"] == nil
    end
  end

  describe "notes update" do
    test "updates a note", %{conn: conn} do
      note = note_fixture()
      contact = Contacts.get_contact(note.contact_id)
      user = Account.get_user(contact.user_id)

      conn =
        conn
        |> authenticate_user(user)
        |> put(~p"/api/notes/#{note.id}", note: @update_attrs)

      response = json_response(conn, 200)["data"]["attributes"]
      assert response["note"] == @update_attrs.note
    end
  end
end
