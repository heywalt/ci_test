defmodule WaltUiWeb.Api.TagsControllerTest do
  use WaltUiWeb.ConnCase, async: true

  import WaltUi.Factory

  describe "index/2" do
    test "returns all tags for the current user", %{conn: conn} do
      user = insert(:user, email: "test@test.com")
      insert(:tag, user: user)
      conn = assign(conn, :current_user, user)

      conn = get(conn, ~p"/api/tags")

      assert data = json_response(conn, 200)["data"]
      assert length(data) == 1
    end

    test "returns empty list when user has no tags", %{conn: conn} do
      user = insert(:user, email: "test@test.com")
      conn = assign(conn, :current_user, user)

      conn = get(conn, ~p"/api/tags")
      assert json_response(conn, 200) == %{"data" => []}
    end
  end

  describe "create/2" do
    test "creates a tag with valid data", %{conn: conn} do
      user = insert(:user, email: "test@test.com")
      conn = assign(conn, :current_user, user)
      params = %{name: "Test Tag", color: "#FF0000"}

      conn = post(conn, ~p"/api/tags", params)
      assert %{"data" => data} = json_response(conn, 201)
      assert data["name"] == "Test Tag"
      assert data["color"] == "#FF0000"
    end

    test "returns error when name is missing", %{conn: conn} do
      user = insert(:user, email: "test@test.com")
      conn = assign(conn, :current_user, user)
      params = %{color: "#FF0000"}

      conn = post(conn, ~p"/api/tags", params)
      assert json_response(conn, 400)
    end

    test "returns error when color is missing", %{conn: conn} do
      user = insert(:user, email: "test@test.com")
      conn = assign(conn, :current_user, user)
      params = %{name: "Test Tag"}

      conn = post(conn, ~p"/api/tags", params)

      assert json_response(conn, 400)
    end

    test "returns error when tag with same name already exists", %{conn: conn} do
      user = insert(:user, email: "test@test.com")
      conn = assign(conn, :current_user, user)
      insert(:tag, name: "Test Tag", user: user)
      params = %{name: "Test Tag", color: "#FF0000"}

      conn = post(conn, ~p"/api/tags", params)
      assert json_response(conn, 422)
    end
  end

  describe "show/2" do
    test "returns a tag when authorized", %{conn: conn} do
      user = insert(:user, email: "test@test.com")
      tag = insert(:tag, user: user)
      conn = assign(conn, :current_user, user)

      conn = get(conn, ~p"/api/tags/#{tag.id}")
      assert %{"data" => data} = json_response(conn, 200)
      assert data["id"] == tag.id
      assert data["name"] == tag.name
      assert data["color"] == tag.color
    end

    test "returns not found when tag doesn't exist", %{conn: conn} do
      user = insert(:user, email: "test@test.com")
      conn = assign(conn, :current_user, user)

      conn = get(conn, ~p"/api/tags/#{Ecto.UUID.generate()}")
      assert json_response(conn, 404)
    end

    test "returns unauthorized when accessing other user's tag", %{conn: conn} do
      user = insert(:user, email: "test@test.com")
      other_user = insert(:user, email: "other@test.com")
      tag = insert(:tag, user: other_user)
      conn = assign(conn, :current_user, user)

      conn = get(conn, ~p"/api/tags/#{tag.id}")
      assert json_response(conn, 401)
    end
  end

  describe "update/2" do
    test "updates a tag when authorized", %{conn: conn} do
      user = insert(:user, email: "test@test.com")
      tag = insert(:tag, user: user)
      conn = assign(conn, :current_user, user)
      params = %{tag: %{name: "Updated Tag", color: "#00FF00"}}

      conn = put(conn, ~p"/api/tags/#{tag.id}", params)
      assert %{"data" => data} = json_response(conn, 200)
      assert data["name"] == "Updated Tag"
      assert data["color"] == "#00FF00"
    end

    test "returns not found when tag doesn't exist", %{conn: conn} do
      user = insert(:user, email: "test@test.com")
      conn = assign(conn, :current_user, user)
      params = %{tag: %{name: "Updated Tag", color: "#00FF00"}}

      conn = put(conn, ~p"/api/tags/#{Ecto.UUID.generate()}", params)
      assert json_response(conn, 404)
    end

    test "returns unauthorized when updating other user's tag", %{conn: conn} do
      user = insert(:user, email: "test@test.com")
      other_user = insert(:user, email: "other@test.com")
      tag = insert(:tag, user: other_user)
      conn = assign(conn, :current_user, user)
      params = %{tag: %{name: "Updated Tag", color: "#00FF00"}}

      conn = put(conn, ~p"/api/tags/#{tag.id}", params)
      assert json_response(conn, 401)
    end

    test "returns error when updating to existing tag name", %{conn: conn} do
      user = insert(:user, email: "test@test.com")
      tag1 = insert(:tag, name: "Tag 1", user: user)
      _tag2 = insert(:tag, name: "Tag 2", user: user)
      conn = assign(conn, :current_user, user)
      params = %{tag: %{name: "Tag 2"}}

      conn = put(conn, ~p"/api/tags/#{tag1.id}", params)
      assert json_response(conn, 422)
    end
  end

  describe "delete/2" do
    test "deletes a tag when authorized", %{conn: conn} do
      user = insert(:user, email: "test@test.com")
      tag = insert(:tag, user: user)
      conn = assign(conn, :current_user, user)

      conn = delete(conn, ~p"/api/tags/#{tag.id}")
      assert response(conn, 204)
    end

    test "returns not found when tag doesn't exist", %{conn: conn} do
      user = insert(:user, email: "test@test.com")
      conn = assign(conn, :current_user, user)

      conn = delete(conn, ~p"/api/tags/#{Ecto.UUID.generate()}")
      assert json_response(conn, 404)
    end

    test "returns unauthorized when deleting other user's tag", %{conn: conn} do
      user = insert(:user, email: "test@test.com")
      other_user = insert(:user, email: "other@test.com")
      tag = insert(:tag, user: other_user)
      conn = assign(conn, :current_user, user)

      conn = delete(conn, ~p"/api/tags/#{tag.id}")
      assert json_response(conn, 401)
    end
  end
end
