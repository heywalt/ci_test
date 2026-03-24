defmodule WaltUi.Skyslope.Auth.Http do
  @moduledoc """
  HTTP Client for interacting with the Skyslope Auth API.
  """
  require Logger

  @spec get_new_tokens(map()) :: {:ok, map()} | {:error, String.t()}
  def get_new_tokens(external_account) do
    token_attrs = %{
      client_id: config()[:client_id],
      grant_type: "refresh_token",
      refresh_token: external_account.refresh_token,
      code_verifier: "_codeVerifier",
      redirect_uri: config()[:redirect_uri]
    }

    client()
    |> Tesla.post("/token", URI.encode_query(token_attrs))
    |> handle_response()
  end

  defp client do
    Tesla.client(
      [
        {Tesla.Middleware.BaseUrl, "https://accounts.skyslope.com/oauth2"},
        Tesla.Middleware.JSON,
        {Tesla.Middleware.Headers, [{"content-type", "application/x-www-form-urlencoded"}]}
      ],
      Tesla.Adapter.Hackney
    )
  end

  defp config do
    Application.get_env(:walt_ui, :skyslope)
  end

  defp handle_response({:ok, %{status: code, body: body}}) when code in 200..299 do
    {:ok, body}
  end

  defp handle_response({:ok, %{status: code, body: body}}) do
    Logger.error("Refresh failed with status #{code}: #{inspect(body)}")

    {:error, "Refresh failed with status #{code}: #{inspect(body)}"}
  end
end
