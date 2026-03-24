defmodule WaltUi.ExternalAccountsAuthHelper do
  @moduledoc """
  Helper functions for interacting with external accounts.
  """

  require Logger

  alias WaltUi.ExternalAccounts
  alias WaltUi.Google.Auth.Http, as: GoogleHttp
  alias WaltUi.Skyslope.Auth.Http, as: SkyslopeHttp

  def get_latest_token(external_account) do
    if caching_enabled?() do
      get_token_with_cache(external_account)
    else
      get_token_without_cache(external_account)
    end
  end

  defp get_token_with_cache(external_account) do
    cache_key = {:external_account_cache, external_account.id}
    now = :os.system_time(:second)

    # Check if we have recent cached data in process dictionary (within last 30 seconds)
    case Process.get(cache_key) do
      {cached_account, timestamp} when is_integer(timestamp) and now - timestamp < 30 ->
        # Use cached data if it's fresh
        check_and_refresh_token(cached_account)

      _ ->
        # Cache miss or stale data, reload from database
        fresh_external_account = ExternalAccounts.get(external_account.id)
        Process.put(cache_key, {fresh_external_account, now})
        check_and_refresh_token(fresh_external_account)
    end
  end

  defp get_token_without_cache(external_account) do
    fresh_external_account = ExternalAccounts.get(external_account.id)
    check_and_refresh_token(fresh_external_account)
  end

  defp caching_enabled? do
    Application.get_env(:walt_ui, :enable_external_account_caching, true)
  end

  defp check_and_refresh_token(external_account) do
    fifteen_minutes_from_now = NaiveDateTime.utc_now() |> NaiveDateTime.add(15, :minute)

    if NaiveDateTime.compare(fifteen_minutes_from_now, external_account.expires_at) == :gt do
      refresh_token(external_account)
    else
      {:ok, external_account.access_token}
    end
  end

  defp refresh_token(%{provider: :google} = external_account) do
    with {:ok, token_attrs} <- GoogleHttp.get_new_tokens(external_account),
         {:ok, updated_ea} <- update_external_account(external_account, token_attrs) do
      # Update the cache with the refreshed account data
      cache_key = {:external_account_cache, external_account.id}
      now = :os.system_time(:second)
      Process.put(cache_key, {updated_ea, now})

      {:ok, updated_ea.access_token}
    else
      {:error, reason} ->
        Logger.error("Failed to refresh token: #{inspect(reason)}")

        {:error, reason}
    end
  end

  defp refresh_token(%{provider: :skyslope} = external_account) do
    with {:ok, token_attrs} <- SkyslopeHttp.get_new_tokens(external_account),
         {:ok, updated_ea} <- update_external_account(external_account, token_attrs) do
      # Update the cache with the refreshed account data
      cache_key = {:external_account_cache, external_account.id}
      now = :os.system_time(:second)
      Process.put(cache_key, {updated_ea, now})

      {:ok, updated_ea.access_token}
    else
      {:error, reason} ->
        Logger.error("Failed to refresh token: #{inspect(reason)}")

        {:error, reason}
    end
  end

  defp update_external_account(external_account, token_attrs) do
    expires_at =
      NaiveDateTime.utc_now()
      |> NaiveDateTime.add(token_attrs["expires_in"], :second)

    token_attrs = Map.merge(token_attrs, %{"expires_at" => expires_at})

    ExternalAccounts.update(external_account, token_attrs)
  end
end
