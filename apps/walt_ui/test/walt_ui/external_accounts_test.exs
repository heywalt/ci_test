defmodule WaltUi.ExternalAccountsTest do
  use Repo.DataCase, async: false

  import WaltUi.Factory

  alias WaltUi.ExternalAccounts
  alias WaltUi.ExternalAccounts.ExternalAccount

  setup_all do
    Tesla.Mock.mock_global(fn
      request ->
        case request do
          %{method: :get, url: "https://oauth2.googleapis.com/gmail/v1/users/profile"} ->
            %Tesla.Env{
              status: 200,
              body:
                Jason.encode!(%{
                  "emailAddress" => "jd@heywalt.ai",
                  "historyId" => "106625",
                  "messagesTotal" => 201,
                  "threadsTotal" => 183
                })
            }

          _ ->
            %Tesla.Env{status: 404, body: "No mock configured for this request..."}
        end
    end)
  end

  setup do
    user = insert(:user, email: "test_external_accounts_#{System.unique_integer()}@example.com")

    {:ok, %{user: user}}
  end

  describe "create/1" do
    test "creates a new external account with valid attributes", %{user: user} do
      expires_at = DateTime.utc_now() |> DateTime.add(1, :hour)

      attrs = %{
        provider: :google,
        access_token: "super_fancy_access_token",
        refresh_token: "legit_refresh_token",
        expires_at: expires_at,
        user_id: user.id,
        token_source: "ios"
      }

      assert {:ok,
              %ExternalAccount{
                provider: :google,
                access_token: "super_fancy_access_token",
                refresh_token: "legit_refresh_token",
                token_source: :ios
              }} = ExternalAccounts.create(attrs)
    end

    test "returns an error tuple with missing attrs", %{user: user} do
      expires_at = DateTime.utc_now() |> DateTime.add(1, :hour)

      attrs = %{
        provider: :google,
        refresh_token: "legit_refresh_token",
        expires_at: expires_at,
        user_id: user.id,
        token_source: "ios"
      }

      assert {:error,
              %Ecto.Changeset{errors: [access_token: {"can't be blank", [validation: :required]}]}} =
               ExternalAccounts.create(attrs)
    end
  end

  describe "fetch/1" do
    test "returns an external account in an ok tuple" do
      %{id: ea_id} = insert(:external_account)

      assert {:ok, %ExternalAccount{}} = ExternalAccounts.fetch(ea_id)
    end

    test "returns not found error when EA doesn't exist" do
      assert {:error, %WaltUi.Error{reason_atom: :not_found}} =
               ExternalAccounts.fetch(Ecto.UUID.generate())
    end
  end

  describe "get/1" do
    test "returns an external account" do
      %{id: ea_id} = insert(:external_account)

      assert %ExternalAccount{id: ^ea_id} = ExternalAccounts.get(ea_id)
    end

    test "returns nil if EA doesn't exist" do
      assert is_nil(ExternalAccounts.get(Ecto.UUID.generate()))
    end
  end

  describe "find_by_provider/2" do
    test "given a list of external accounts, find the one for the provider given", %{user: user} do
      google_ea = insert(:external_account, provider: :google, user: user)
      skyslope_ea = insert(:external_account, provider: :skyslope, user: user)

      assert {:ok, %{provider: :google}} =
               ExternalAccounts.find_by_provider([google_ea, skyslope_ea], :google)
    end

    test "returns {:error, :not_found} if desired EA doesn't exist", %{user: user} do
      skyslope_ea = insert(:external_account, provider: :skyslope, user: user)

      assert {:error, :not_found} = ExternalAccounts.find_by_provider([skyslope_ea], :google)
    end
  end

  describe "create_from_mobile/1" do
    test "creates an extrnal account with a mobile-specific payload", %{user: user} do
      expires_in = DateTime.add(DateTime.utc_now(), 1, :hour) |> DateTime.to_unix()

      attrs = %{
        "provider" => "google",
        "access_token" => "super_fancy_access_token",
        "refresh_token" => "legit_refresh_token",
        "expires_in" => expires_in,
        "token_source" => "android",
        "user_id" => user.id
      }

      assert {:ok,
              %ExternalAccount{
                provider: :google,
                access_token: "super_fancy_access_token",
                refresh_token: "legit_refresh_token",
                token_source: :android
              }} = ExternalAccounts.create_from_mobile(attrs)
    end
  end

  describe "create_from_web/2" do
    test "creates external account for a given user with different email", %{user: user} do
      # User has work@gmail.com but is linking personal@gmail.com
      expires_at = DateTime.add(DateTime.utc_now(), 1, :hour) |> DateTime.to_unix()

      auth_payload = %{
        uid: "google_uid_123",
        info: %{
          # Different from user.email
          email: "personal@gmail.com"
        },
        credentials: %{
          token: "google_access_token",
          refresh_token: "google_refresh_token",
          expires_at: expires_at
        }
      }

      assert {:ok, %ExternalAccount{} = ea} =
               ExternalAccounts.create_from_web(user, auth_payload, "google")

      assert ea.user_id == user.id
      assert ea.email == "personal@gmail.com"
      assert ea.provider == :google
      assert ea.access_token == "google_access_token"
      assert ea.refresh_token == "google_refresh_token"
      assert ea.token_source == :web
    end

    test "updates existing external account when user already has one", %{user: user} do
      # Create existing external account
      existing_ea =
        insert(:external_account,
          user: user,
          provider: :google,
          email: "old@gmail.com",
          access_token: "old_token"
        )

      expires_at = DateTime.add(DateTime.utc_now(), 1, :hour) |> DateTime.to_unix()

      auth_payload = %{
        uid: "google_uid_123",
        info: %{
          email: "new@gmail.com"
        },
        credentials: %{
          token: "new_access_token",
          refresh_token: "new_refresh_token",
          expires_at: expires_at
        }
      }

      assert {:ok, %ExternalAccount{} = updated_ea} =
               ExternalAccounts.create_from_web(user, auth_payload, "google")

      # Should update the existing external account, not create a new one
      assert updated_ea.id == existing_ea.id
      assert updated_ea.email == "new@gmail.com"
      assert updated_ea.access_token == "new_access_token"
      assert updated_ea.refresh_token == "new_refresh_token"
    end
  end

  describe "update/2" do
    test "updates an existing external account" do
      ea = insert(:external_account)
      expires_at = DateTime.utc_now() |> DateTime.add(1, :hour)

      update_attrs = %{refresh_token: "new_refresh_token", expires_at: expires_at}

      assert {:ok, %{refresh_token: "new_refresh_token"}} =
               ExternalAccounts.update(ea, update_attrs)
    end
  end

  describe "delete/1" do
    test "deletes an existing external account" do
      ea = insert(:external_account)

      assert {:ok, %ExternalAccount{}} = ExternalAccounts.delete(ea)
      assert is_nil(Repo.get(ExternalAccount, ea.id))
    end
  end

  describe "for_user/2" do
    test "returns external account for the user given a provider", %{user: user} do
      %{id: id} = insert(:external_account, user: user, provider: :google)
      insert(:external_account, user: user, provider: :skyslope)

      assert %ExternalAccount{id: ^id} = ExternalAccounts.for_user(user, :google)
    end

    test "returns nil if external account doesn't exist for the desired provider", %{user: user} do
      insert(:external_account, user: user, provider: :google)

      assert is_nil(ExternalAccounts.for_user(user, :skyslope))
    end
  end
end
