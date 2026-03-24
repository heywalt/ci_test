defmodule WaltUiWeb.Api.Controllers.UserControllerTest do
  use WaltUiWeb.ConnCase

  import WaltUi.Factory
  import WaltUi.Helpers

  @update_attrs %{
    avatar: "/brandnewimage.jpg",
    type: "agent"
  }

  setup ctx do
    [conn: put_req_header(ctx.conn, "accept", "application/json"), user: insert(:user)]
  end

  describe "GET /api/user" do
    test "renders a user", ctx do
      user_id = ctx.user.id

      result =
        ctx.conn
        |> authenticate_user(ctx.user)
        |> get(~p"/api/user")

      assert %{"id" => ^user_id, "attributes" => %{"external_accounts" => []}} =
               json_response(result, 200)["data"]
    end

    test "renders a user with an external account", ctx do
      user_id = ctx.user.id

      %{id: ea_id} = insert(:external_account, user: ctx.user)

      result =
        ctx.conn
        |> authenticate_user(ctx.user)
        |> get(~p"/api/user")

      assert %{
               "id" => ^user_id,
               "attributes" => %{
                 "external_accounts" => [%{"provider" => "google", "id" => ^ea_id}]
               }
             } =
               json_response(result, 200)["data"]
    end
  end

  describe "PUT /api/user" do
    test "renders user with valid data", ctx do
      avatar = @update_attrs.avatar
      type = @update_attrs.type
      user_id = ctx.user.id

      result =
        ctx.conn
        |> authenticate_user(ctx.user)
        |> put(~p"/api/user", @update_attrs)

      assert %{"id" => ^user_id, "attributes" => %{"avatar" => response_avatar, "type" => ^type}} =
               json_response(result, 200)["data"]

      assert String.contains?(response_avatar, avatar)
    end
  end

  describe "DELETE /api/user" do
    test "deletes user", ctx do
      contact_1 = await_contact(user_id: ctx.user.id)
      contact_2 = await_contact(user_id: ctx.user.id)

      result =
        ctx.conn
        |> authenticate_user(ctx.user)
        |> delete(~p"/api/user")

      assert result.status == 204

      # data deleted
      refute Repo.reload(contact_1)
      refute Repo.reload(contact_2)
      refute Repo.reload(ctx.user)
    end
  end
end
