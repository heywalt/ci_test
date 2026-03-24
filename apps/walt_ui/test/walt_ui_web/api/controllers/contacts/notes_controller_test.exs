defmodule WaltUiWeb.Api.Controllers.Contacts.NotesControllerTest do
  use WaltUiWeb.ConnCase

  import WaltUi.Factory

  alias WaltUi.Account

  @create_attrs %{
    note: "this is a test note"
  }

  setup %{conn: conn} do
    {:ok, conn: put_req_header(conn, "accept", "application/json")}
  end

  describe "contacts notes index" do
    test "lists all notes for a contact", %{conn: conn} do
      contact = insert(:contact)
      user = Account.get_user(contact.user_id)

      conn =
        conn
        |> authenticate_user(user)
        |> get(~p"/api/contacts/#{contact.id}/notes")

      assert json_response(conn, 200)["data"] == []
    end

    test "fails when unauthorized", %{conn: conn} do
      contact = insert(:contact)

      # different unauthorized user
      user = insert(:user)

      conn =
        conn
        |> authenticate_user(user)
        |> get(~p"/api/contacts/#{contact.id}/notes")

      assert json_response(conn, 401)
    end
  end

  describe "create contact note" do
    test "renders note when data is valid", %{conn: conn} do
      contact = insert(:contact)
      user = Account.get_user(contact.user_id)

      result =
        conn
        |> authenticate_user(user)
        |> post(~p"/api/contacts/#{contact.id}/notes", @create_attrs)

      assert %{"id" => id} = json_response(result, 200)["data"]

      conn =
        conn
        |> authenticate_user(user)
        |> get(~p"/api/notes/#{id}")

      assert %{
               "id" => ^id,
               "attributes" => %{"note" => "this is a test note"}
             } = json_response(conn, 200)["data"]
    end

    test "renders errors when data is invalid", %{conn: conn} do
      contact = insert(:contact)
      user = Account.get_user(contact.user_id)

      conn =
        conn
        |> authenticate_user(user)
        |> post(~p"/api/contacts/#{contact.id}/notes", note: nil)

      assert json_response(conn, 422)["errors"] != %{}
    end
  end
end
