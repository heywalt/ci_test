defmodule WaltUi.Notifications.Fcm.Http do
  @moduledoc """
  HTTP Client for interacting with the Firebase Cloud Messaging API
  """
  require Logger

  @base_url "https://fcm.googleapis.com/v1/projects/heywalt-e8db0"

  @spec send_notification(String.t(), map()) :: {:ok, map()} | {:error, atom()}
  def send_notification(token, payload) do
    request = %{
      message: %{
        token: token,
        notification: %{
          title: payload.title,
          body: payload.body
        },
        data: payload.data
      }
    }

    with {:ok, access_token} <- get_auth_token() do
      access_token
      |> client()
      |> Tesla.post("/messages:send", request)
      |> handle_response()
    end
  end

  defp get_auth_token do
    case Goth.fetch(WaltUi.Goth) do
      {:ok, token} -> {:ok, token.token}
      {:error, _} -> {:error, :google_not_authenticated}
    end
  end

  defp client(access_token) do
    Tesla.client(
      [
        {Tesla.Middleware.BaseUrl, @base_url},
        Tesla.Middleware.JSON,
        {Tesla.Middleware.BearerAuth, token: access_token},
        {Tesla.Middleware.Retry,
         delay: 500,
         max_delay: 1_000,
         max_retries: 3,
         should_retry: fn
           {:error, :timeout} -> true
           {:error, :checkout_timeout} -> true
           {:ok, %{status: 500}} -> true
           {:ok, %{status: 503}} -> true
           _else -> false
         end}
      ],
      Tesla.Adapter.Hackney
    )
  end

  defp handle_response({:ok, %{status: code, body: body}}) when code in 200..299 do
    {:ok, body}
  end

  defp handle_response({:ok, %{status: 404}}) do
    Logger.warning("FCM token not found (404)")
    {:error, :not_found}
  end

  defp handle_response({:ok, %{status: 410}}) do
    Logger.warning("FCM token expired/gone (410)")
    {:error, :gone}
  end

  defp handle_response({:ok, %{status: 401}}) do
    Logger.warning("Unauthorized FCM request (401)")
    {:error, :unauthorized}
  end

  defp handle_response({:ok, %{status: 400, body: body}}) do
    Logger.warning("Bad FCM request (400)", details: inspect(body))
    {:error, :bad_request}
  end

  defp handle_response({:ok, response}) do
    Logger.warning("Unexpected Response from FCM", details: inspect(response))
    {:error, :unexpected_response}
  end

  defp handle_response({:error, response}) do
    Logger.warning("Unexpected Error Response from FCM", details: inspect(response))
    {:error, :unexpected_error}
  end
end
