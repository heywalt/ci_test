defmodule WaltUi.ExternalAccountsAuthHelperTest do
  use Repo.DataCase, async: false
  use Mimic

  import WaltUi.AccountFixtures

  alias WaltUi.ExternalAccounts
  alias WaltUi.ExternalAccountsAuthHelper
  alias WaltUi.Google.Auth.Http, as: GoogleHttp
  alias WaltUi.Skyslope.Auth.Http, as: SkyslopeHttp

  setup :verify_on_exit!

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

  describe "get_latest_token/1 for Google" do
    setup do
      user = user_fixture()

      {:ok, %{user: user}}
    end

    test "Returns existing token if not expired", %{user: user} do
      attrs = %{
        user_id: user.id,
        provider: "google",
        provider_user_id: "123",
        access_token: "good_token",
        refresh_token: "refresh_token",
        token_source: :web,
        expires_at: NaiveDateTime.utc_now() |> NaiveDateTime.add(60, :minute)
      }

      assert {:ok, ea} = ExternalAccounts.create(attrs)

      reject(&GoogleHttp.get_new_tokens/1)

      assert {:ok, "good_token"} = ExternalAccountsAuthHelper.get_latest_token(ea)
    end

    test "Fetches a new token if the current one has expired", %{user: user} do
      attrs = %{
        user_id: user.id,
        provider: "google",
        provider_user_id: "123",
        access_token: "old_token",
        refresh_token: "old_refresh_token",
        token_source: :web,
        expires_at: NaiveDateTime.utc_now() |> NaiveDateTime.add(-15, :minute)
      }

      assert {:ok, ea} = ExternalAccounts.create(attrs)

      expect(GoogleHttp, :get_new_tokens, fn _ ->
        {:ok, %{"access_token" => "legit_new_token", "expires_in" => 3599}}
      end)

      assert {:ok, "legit_new_token"} = ExternalAccountsAuthHelper.get_latest_token(ea)
    end
  end

  describe "get_latest_token/1 for Skyslope" do
    setup do
      user = user_fixture()

      {:ok, %{user: user}}
    end

    test "Returns existing token if not expired", %{user: user} do
      attrs = %{
        user_id: user.id,
        provider: "skyslope",
        provider_user_id: "123",
        access_token: "good_token",
        refresh_token: "refresh_token",
        token_source: :web,
        expires_at: NaiveDateTime.utc_now() |> NaiveDateTime.add(60, :minute)
      }

      assert {:ok, ea} = ExternalAccounts.create(attrs)

      reject(&SkyslopeHttp.get_new_tokens/1)

      assert {:ok, "good_token"} = ExternalAccountsAuthHelper.get_latest_token(ea)
    end

    test "Fetches a new token if the current one has expired", %{user: user} do
      attrs = %{
        user_id: user.id,
        provider: "skyslope",
        provider_user_id: "123",
        access_token: "old_token",
        refresh_token: "old_refresh_token",
        token_source: :web,
        expires_at: NaiveDateTime.utc_now() |> NaiveDateTime.add(-15, :minute)
      }

      assert {:ok, ea} = ExternalAccounts.create(attrs)

      expect(SkyslopeHttp, :get_new_tokens, fn _ ->
        {:ok, %{"access_token" => "legit_new_token", "expires_in" => 3599}}
      end)

      assert {:ok, "legit_new_token"} = ExternalAccountsAuthHelper.get_latest_token(ea)
    end
  end
end
