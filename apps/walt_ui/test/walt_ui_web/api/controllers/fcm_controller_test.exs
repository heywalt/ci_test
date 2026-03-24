defmodule WaltUiWeb.Api.Controllers.FcmControllerTest do
  use WaltUiWeb.ConnCase

  import Ecto.Query
  import WaltUi.Factory

  alias WaltUi.Notifications.FcmToken

  setup ctx do
    [conn: put_req_header(ctx.conn, "accept", "application/json"), user: insert(:user)]
  end

  describe "POST /api/user/fcm-tokens" do
    test "creates FCM token with valid data", ctx do
      token = "new_fcm_token_abc123"

      result =
        ctx.conn
        |> authenticate_user(ctx.user)
        |> post(~p"/api/user/fcm-tokens", %{token: token})

      assert result.status == 201

      # Token was created in database
      fcm_token = Repo.get_by(FcmToken, token: token)
      assert fcm_token
      assert fcm_token.user_id == ctx.user.id
    end

    test "returns error with invalid data", ctx do
      result =
        ctx.conn
        |> authenticate_user(ctx.user)
        |> post(~p"/api/user/fcm-tokens", %{})

      assert result.status == 422
    end

    test "requires authentication", ctx do
      result = post(ctx.conn, ~p"/api/user/fcm-tokens", %{token: "test"})
      assert result.status == 401
    end

    test "is idempotent for duplicate tokens", ctx do
      token = "duplicate_token_xyz"

      result1 =
        ctx.conn
        |> authenticate_user(ctx.user)
        |> post(~p"/api/user/fcm-tokens", %{token: token})

      assert result1.status == 201

      result2 =
        ctx.conn
        |> authenticate_user(ctx.user)
        |> post(~p"/api/user/fcm-tokens", %{token: token})

      assert result2.status == 201

      # Only one token in database
      assert [_token] = Repo.all(from t in FcmToken, where: t.token == ^token)
    end
  end

  describe "PUT /api/user/fcm-tokens/:id" do
    setup ctx do
      fcm_token = insert(:fcm_token, user_id: ctx.user.id)
      [fcm_token: fcm_token]
    end

    test "updates token successfully", ctx do
      new_token = "updated_token_456"

      result =
        ctx.conn
        |> authenticate_user(ctx.user)
        |> put(~p"/api/user/fcm-tokens/#{ctx.fcm_token.id}", %{token: new_token})

      assert result.status == 200

      # Token was updated
      updated = Repo.get(FcmToken, ctx.fcm_token.id)
      assert updated.token == new_token
    end

    test "returns 401 for unauthorized update", ctx do
      other_user = insert(:user)

      result =
        ctx.conn
        |> authenticate_user(other_user)
        |> put(~p"/api/user/fcm-tokens/#{ctx.fcm_token.id}", %{token: "new_token"})

      assert result.status == 401
    end

    test "returns 404 for non-existent token", ctx do
      result =
        ctx.conn
        |> authenticate_user(ctx.user)
        |> put(~p"/api/user/fcm-tokens/#{UUID.uuid4()}", %{token: "new_token"})

      assert result.status == 404
    end

    test "requires authentication", ctx do
      result = put(ctx.conn, ~p"/api/user/fcm-tokens/#{ctx.fcm_token.id}", %{token: "test"})
      assert result.status == 401
    end
  end

  describe "DELETE /api/user/fcm-tokens/:id" do
    setup ctx do
      fcm_token = insert(:fcm_token, user_id: ctx.user.id)
      [fcm_token: fcm_token]
    end

    test "deletes token successfully", ctx do
      result =
        ctx.conn
        |> authenticate_user(ctx.user)
        |> delete(~p"/api/user/fcm-tokens/#{ctx.fcm_token.id}")

      assert result.status == 204

      # Token was deleted
      refute Repo.get(FcmToken, ctx.fcm_token.id)
    end

    test "returns 401 for unauthorized delete", ctx do
      other_user = insert(:user)

      result =
        ctx.conn
        |> authenticate_user(other_user)
        |> delete(~p"/api/user/fcm-tokens/#{ctx.fcm_token.id}")

      assert result.status == 401

      # Token still exists
      assert Repo.get(FcmToken, ctx.fcm_token.id)
    end

    test "returns 404 for non-existent token", ctx do
      result =
        ctx.conn
        |> authenticate_user(ctx.user)
        |> delete(~p"/api/user/fcm-tokens/#{UUID.uuid4()}")

      assert result.status == 404
    end

    test "requires authentication", ctx do
      result = delete(ctx.conn, ~p"/api/user/fcm-tokens/#{ctx.fcm_token.id}")
      assert result.status == 401
    end
  end
end
