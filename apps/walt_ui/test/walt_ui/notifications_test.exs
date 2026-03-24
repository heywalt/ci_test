defmodule WaltUi.NotificationsTest do
  use WaltUi.CqrsCase

  import WaltUi.Factory

  alias WaltUi.Notifications
  alias WaltUi.Notifications.FcmToken

  describe "FcmToken schema" do
    test "changeset requires token and user_id" do
      changeset = FcmToken.changeset(%FcmToken{}, %{})
      refute changeset.valid?
      assert %{token: ["can't be blank"], user_id: ["can't be blank"]} = errors_on(changeset)
    end

    test "changeset is valid with token and user_id" do
      user = insert(:user)
      changeset = FcmToken.changeset(%FcmToken{}, %{token: "test_token_123", user_id: user.id})
      assert changeset.valid?
    end

    test "enforces unique constraint on token" do
      user = insert(:user)
      insert(:fcm_token, token: "duplicate_token", user_id: user.id)

      assert {:error, changeset} =
               %FcmToken{}
               |> FcmToken.changeset(%{token: "duplicate_token", user_id: user.id})
               |> Repo.insert()

      assert %{token: ["has already been taken"]} = errors_on(changeset)
    end
  end

  describe "register_device/2" do
    setup do
      [user: insert(:user)]
    end

    test "creates new FCM token successfully", ctx do
      token = "fcm_token_abc123"
      assert {:ok, %FcmToken{} = fcm_token} = Notifications.register_device(ctx.user, token)
      assert fcm_token.token == token
      assert fcm_token.user_id == ctx.user.id
    end

    test "returns error changeset with invalid data", ctx do
      assert {:error, %Ecto.Changeset{}} = Notifications.register_device(ctx.user, nil)
    end

    test "returns existing token if already registered (find_or_create)", ctx do
      token = "fcm_token_duplicate"
      assert {:ok, %FcmToken{id: first_id}} = Notifications.register_device(ctx.user, token)
      assert {:ok, %FcmToken{id: second_id}} = Notifications.register_device(ctx.user, token)
      assert first_id == second_id
    end
  end

  describe "update_device_token/3" do
    setup do
      user = insert(:user)
      fcm_token = insert(:fcm_token, user_id: user.id)
      [user: user, fcm_token: fcm_token]
    end

    test "updates token successfully", ctx do
      new_token = "new_fcm_token_xyz"

      assert {:ok, %FcmToken{} = updated} =
               Notifications.update_device_token(ctx.fcm_token.id, ctx.user, new_token)

      assert updated.token == new_token
      assert updated.id == ctx.fcm_token.id
    end

    test "prevents unauthorized updates", ctx do
      other_user = insert(:user)
      new_token = "new_fcm_token_xyz"

      assert {:error, :unauthorized} =
               Notifications.update_device_token(ctx.fcm_token.id, other_user, new_token)
    end

    test "returns error for non-existent token", ctx do
      assert {:error, :not_found} =
               Notifications.update_device_token(UUID.uuid4(), ctx.user, "new_token")
    end
  end

  describe "unregister_device/2" do
    setup do
      user = insert(:user)
      fcm_token = insert(:fcm_token, user_id: user.id)
      [user: user, fcm_token: fcm_token]
    end

    test "deletes token successfully", ctx do
      assert {:ok, %FcmToken{}} = Notifications.unregister_device(ctx.fcm_token.id, ctx.user)
      refute Repo.get(FcmToken, ctx.fcm_token.id)
    end

    test "prevents unauthorized deletion", ctx do
      other_user = insert(:user)

      assert {:error, :unauthorized} =
               Notifications.unregister_device(ctx.fcm_token.id, other_user)

      # Token should still exist
      assert Repo.get(FcmToken, ctx.fcm_token.id)
    end

    test "returns error for non-existent token", ctx do
      assert {:error, :not_found} = Notifications.unregister_device(UUID.uuid4(), ctx.user)
    end
  end

  describe "get_user_tokens/1" do
    test "returns all user's tokens" do
      user = insert(:user)
      token1 = insert(:fcm_token, user_id: user.id)
      token2 = insert(:fcm_token, user_id: user.id)

      # Create token for different user
      other_user = insert(:user)
      insert(:fcm_token, user_id: other_user.id)

      tokens = Notifications.get_user_tokens(user)
      assert length(tokens) == 2
      assert token1 in tokens
      assert token2 in tokens
    end

    test "returns empty list for user with no tokens" do
      user = insert(:user)
      assert [] = Notifications.get_user_tokens(user)
    end
  end
end
