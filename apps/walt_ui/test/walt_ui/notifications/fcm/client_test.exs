defmodule WaltUi.Notifications.Fcm.ClientTest do
  use Repo.DataCase, async: true
  use Mimic

  import WaltUi.Factory

  alias WaltUi.Notifications.Fcm.Client
  alias WaltUi.Notifications.Fcm.Http

  describe "send_notification/4" do
    test "sends to all user devices" do
      user = insert(:user)
      token1 = insert(:fcm_token, user_id: user.id)
      token2 = insert(:fcm_token, user_id: user.id)

      expect(Http, :send_notification, 2, fn token, payload ->
        assert token in [token1.token, token2.token]
        assert %{title: "Test Title", body: "Test Body", data: %{key: "value"}} = payload
        {:ok, %{}}
      end)

      assert {:ok, 2} =
               Client.send_notification(user.id, "Test Title", "Test Body", %{key: "value"})
    end

    test "handles user with no devices" do
      user = insert(:user)
      reject(&Http.send_notification/2)

      assert {:ok, 0} = Client.send_notification(user.id, "Test", "Body")
    end

    test "removes invalid tokens on 404 response" do
      user = insert(:user)
      token = insert(:fcm_token, user_id: user.id)

      expect(Http, :send_notification, fn _token, _payload ->
        {:error, :not_found}
      end)

      assert {:ok, 0} = Client.send_notification(user.id, "Test", "Body")

      # Token should be deleted
      refute Repo.get(WaltUi.Notifications.FcmToken, token.id)
    end

    test "removes invalid tokens on 410 response" do
      user = insert(:user)
      token = insert(:fcm_token, user_id: user.id)

      expect(Http, :send_notification, fn _token, _payload ->
        {:error, :gone}
      end)

      assert {:ok, 0} = Client.send_notification(user.id, "Test", "Body")

      # Token should be deleted
      refute Repo.get(WaltUi.Notifications.FcmToken, token.id)
    end

    test "continues sending to other devices if one fails" do
      user = insert(:user)
      token1 = insert(:fcm_token, user_id: user.id)
      token2 = insert(:fcm_token, user_id: user.id)

      expect(Http, :send_notification, 2, fn token, _payload ->
        if token == token1.token do
          {:error, :gone}
        else
          {:ok, %{}}
        end
      end)

      assert {:ok, 1} = Client.send_notification(user.id, "Test", "Body")

      # First token deleted, second remains
      refute Repo.get(WaltUi.Notifications.FcmToken, token1.id)
      assert Repo.get(WaltUi.Notifications.FcmToken, token2.id)
    end
  end

  describe "send_notification_to_token/4" do
    test "sends successfully to specific token" do
      token = "specific_token_123"

      expect(Http, :send_notification, fn ^token, payload ->
        assert %{title: "Title", body: "Body", data: %{}} = payload
        {:ok, %{}}
      end)

      assert {:ok, %{}} = Client.send_notification_to_token(token, "Title", "Body")
    end

    test "includes data in payload" do
      token = "token_abc"

      expect(Http, :send_notification, fn ^token, payload ->
        assert %{data: %{custom: "data", foo: "bar"}} = payload
        {:ok, %{}}
      end)

      assert {:ok, %{}} =
               Client.send_notification_to_token(token, "Title", "Body", %{
                 custom: "data",
                 foo: "bar"
               })
    end

    test "returns error on failure" do
      expect(Http, :send_notification, fn _token, _payload ->
        {:error, :unauthorized}
      end)

      assert {:error, :unauthorized} = Client.send_notification_to_token("token", "Title", "Body")
    end
  end
end
