defmodule WaltUiWeb.Api.Controllers.Contacts.EventsControllerTest do
  use WaltUiWeb.ConnCase

  import WaltUi.ContactsFixtures
  import WaltUi.Factory

  alias WaltUi.Account

  @create_attrs %{
    type: "selling",
    event: "met"
  }

  @invalid_create_attrs %{
    type: "buying",
    event: "listed_property"
  }

  setup %{conn: conn} do
    {:ok, conn: put_req_header(conn, "accept", "application/json")}
  end

  describe "contacts events index" do
    test "Returns an empty set of events when none exist yet", %{conn: conn} do
      contact = insert(:contact)
      user = Account.get_user(contact.user_id)

      conn =
        conn
        |> authenticate_user(user)
        |> get(~p"/api/contacts/#{contact.id}/events")

      assert json_response(conn, 200)["data"] == []
    end

    test "lists all events for a contact", %{conn: conn} do
      contact = insert(:contact)
      user = Account.get_user(contact.user_id)
      event_fixture(%{contact_id: contact.id})

      conn =
        conn
        |> authenticate_user(user)
        |> get(~p"/api/contacts/#{contact.id}/events")

      response = json_response(conn, 200)["data"]
      assert %{"id" => _id} = Enum.at(response, 0)
    end

    test "fails when unauthorized", %{conn: conn} do
      contact = insert(:contact)

      # different unauthorized user
      user = insert(:user)

      conn =
        conn
        |> authenticate_user(user)
        |> get(~p"/api/contacts/#{contact.id}/events")

      assert json_response(conn, 401)
    end
  end

  describe "create contact event" do
    test "renders events when data is valid", %{conn: conn} do
      contact = insert(:contact)
      user = Account.get_user(contact.user_id)

      result =
        conn
        |> authenticate_user(user)
        |> post(~p"/api/contacts/#{contact.id}/events", @create_attrs)

      assert %{"id" => _id} = json_response(result, 200)["data"]

      conn =
        conn
        |> authenticate_user(user)
        |> get(~p"/api/contacts/#{contact.id}/events")

      response = json_response(conn, 200)["data"]

      assert %{
               "id" => _id,
               "attributes" => %{"event" => "met"}
             } = Enum.at(response, 0)
    end

    test "renders errors when data is invalid", %{conn: conn} do
      contact = insert(:contact)
      user = Account.get_user(contact.user_id)

      conn =
        conn
        |> authenticate_user(user)
        |> post(~p"/api/contacts/#{contact.id}/events", @invalid_create_attrs)

      assert json_response(conn, 422)["errors"] != %{}
    end
  end
end
