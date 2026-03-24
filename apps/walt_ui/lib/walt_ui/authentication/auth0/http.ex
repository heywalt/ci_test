defmodule WaltUi.Authentication.Auth0.Http do
  @moduledoc """
  HTTP Client for interacting with the Auth0 API.
  """

  require Logger

  @spec fetch_user(String.t()) :: {:ok, map()} | {:error, atom()}
  def fetch_user(auth0_user_id) do
    with {:ok, access_token} <- fetch_api_access_token() do
      access_token
      |> client()
      |> Tesla.get("/api/v2/users/#{auth0_user_id}")
      |> handle_response()
    end
  end

  defp config do
    Application.get_env(:walt_ui, WaltUi.Auth0)
  end

  defp client(access_token) do
    Tesla.client(
      [
        {Tesla.Middleware.BaseUrl, config()[:base_url]},
        Tesla.Middleware.JSON,
        {Tesla.Middleware.BearerAuth, token: access_token}
      ],
      Tesla.Adapter.Hackney
    )
  end

  defp fetch_api_access_token do
    base_url = config()[:base_url]

    case PrimaAuth0Ex.token_for(base_url <> "/api/v2/") do
      {:ok, token} ->
        {:ok, token}

      {:error, request_error} ->
        {:error, request_error}
    end
  end

  defp handle_response({:ok, %{status: code, body: body}}) when code in 200..299 do
    {:ok, body}
  end

  defp handle_response({:ok, %{status: code}}) when code == 404 do
    Logger.warning("User not found in Auth0.")
    {:error, :not_found}
  end

  defp handle_response({:ok, %{status: code}}) when code == 401 do
    Logger.warning("Unauthorized request to Auth0.")

    {:error, :unauthorized}
  end

  defp handle_response({:ok, response}) do
    Logger.warning("Unexpected Response from Auth0", details: inspect(response))

    {:error, :unexpected_response}
  end

  defp handle_response({:error, response}) do
    Logger.warning("Unexpected Error Response from Auth0", details: inspect(response))

    {:error, :unexpected_error}
  end
end
