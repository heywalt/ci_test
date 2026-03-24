defmodule WaltUi.Google.Auth.Http do
  @moduledoc """
  HTTP Client for interacting with the Google Auth API.
  """
  require Logger

  @spec get_new_tokens(map()) :: {:ok, map()} | {:error, String.t()}
  def get_new_tokens(external_account) do
    token_attrs = get_token_attrs(external_account)

    client()
    |> Tesla.post("/token", URI.encode_query(token_attrs))
    |> handle_response()
  end

  defp client do
    Tesla.client(
      [
        {Tesla.Middleware.BaseUrl, "https://oauth2.googleapis.com"},
        Tesla.Middleware.JSON,
        {Tesla.Middleware.Headers, [{"content-type", "application/x-www-form-urlencoded"}]}
      ],
      Tesla.Adapter.Hackney
    )
  end

  defp config do
    Application.get_env(:walt_ui, :google)
  end

  defp get_token_attrs(%{token_source: source} = external_account)
       when source in [:android, "android"] do
    %{
      client_id: config()[:android_client_id],
      refresh_token: external_account.refresh_token,
      grant_type: "refresh_token"
    }
  end

  defp get_token_attrs(%{token_source: source} = external_account) when source in [:ios, "ios"] do
    %{
      client_id: config()[:ios_client_id],
      refresh_token: external_account.refresh_token,
      grant_type: "refresh_token"
    }
  end

  defp get_token_attrs(%{token_source: source} = external_account) when source in [:web, "web"] do
    %{
      client_id: config()[:client_id],
      client_secret: config()[:client_secret],
      refresh_token: external_account.refresh_token,
      grant_type: "refresh_token"
    }
  end

  defp handle_response({:ok, %{status: code, body: body}}) when code in 200..299 do
    {:ok, body}
  end

  defp handle_response({:ok, %{status: code, body: body}}) do
    Logger.error("Refresh failed with status #{code}: #{inspect(body)}")

    {:error, "Refresh failed with status #{code}: #{inspect(body)}"}
  end
end
