defmodule WaltUiWeb.Api.ContactTagsControllerTest do
  use WaltUiWeb.ConnCase, async: true

  import WaltUi.Factory

  describe "create/2" do
    test "creates a contact tag with valid data", %{conn: conn} do
      user = insert(:user, email: "test@test.com")
      contact = insert(:contact, user_id: user.id)
      tag = insert(:tag, user: user)
      conn = assign(conn, :current_user, user)
      params = %{contact_id: contact.id, tag_id: tag.id}

      conn = post(conn, ~p"/api/contacts/#{contact.id}/tags", params)
      assert %{"data" => data} = json_response(conn, 201)
      assert data["contact_id"] == contact.id
      assert data["tag_id"] == tag.id
    end

    test "creates contact tag with non-existent contact", %{conn: conn} do
      user = insert(:user, email: "test@test.com")
      tag = insert(:tag, user: user)
      conn = assign(conn, :current_user, user)
      contact_id = Ecto.UUID.generate()
      params = %{tag_id: tag.id, contact_id: contact_id}

      conn = post(conn, ~p"/api/contacts/#{contact_id}/tags", params)
      assert %{"data" => data} = json_response(conn, 201)
      assert data["contact_id"] == contact_id
      assert data["tag_id"] == tag.id
    end

    test "returns error when tag_id is missing", %{conn: conn} do
      user = insert(:user, email: "test@test.com")
      contact = insert(:contact, user_id: user.id)
      conn = assign(conn, :current_user, user)
      params = %{contact_id: contact.id}

      conn = post(conn, ~p"/api/contacts/#{contact.id}/tags", params)
      assert json_response(conn, 400)
    end

    test "returns error when contact tag already exists", %{conn: conn} do
      user = insert(:user, email: "test@test.com")
      contact = insert(:contact, user_id: user.id)
      tag = insert(:tag, user: user)
      _contact_tag = insert(:contact_tag, user: user, contact_id: contact.id, tag: tag)
      conn = assign(conn, :current_user, user)
      params = %{contact_id: contact.id, tag_id: tag.id}

      conn = post(conn, ~p"/api/contacts/#{contact.id}/tags", params)
      assert json_response(conn, 422)
    end
  end

  describe "delete/2" do
    test "deletes a contact tag when authorized", %{conn: conn} do
      user = insert(:user, email: "test@test.com")
      contact = insert(:contact, user_id: user.id)
      tag = insert(:tag, user: user)
      insert(:contact_tag, user: user, contact_id: contact.id, tag: tag)
      conn = assign(conn, :current_user, user)

      conn = delete(conn, ~p"/api/contacts/#{contact.id}/tags/#{tag.id}")
      assert response(conn, 204)
    end

    test "returns not found when contact tag doesn't exist", %{conn: conn} do
      user = insert(:user, email: "test@test.com")
      conn = assign(conn, :current_user, user)

      conn = delete(conn, ~p"/api/contacts/#{Ecto.UUID.generate()}/tags/#{Ecto.UUID.generate()}")
      assert json_response(conn, 404)
    end

    test "returns unauthorized when deleting other user's contact tag", %{conn: conn} do
      user = insert(:user, email: "test@test.com")
      other_user = insert(:user, email: "other@test.com")
      contact = insert(:contact, user_id: other_user.id)
      tag = insert(:tag, user: other_user)
      insert(:contact_tag, user: other_user, contact_id: contact.id, tag: tag)
      conn = assign(conn, :current_user, user)

      conn = delete(conn, ~p"/api/contacts/#{contact.id}/tags/#{tag.id}")
      assert json_response(conn, 401)
    end
  end
end
