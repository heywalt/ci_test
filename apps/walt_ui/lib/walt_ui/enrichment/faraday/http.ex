defmodule WaltUi.Enrichment.Faraday.Http do
  @moduledoc """
  HTTP Client for interacting with the Faraday API.
  """
  require Logger

  @spec fetch_contact(map()) :: {:ok, map()} | {:error, atom()}
  def fetch_contact(request) do
    client()
    |> Tesla.post("", request)
    |> handle_response()
  end

  defp config do
    Application.get_env(:walt_ui, WaltUi.Faraday)
  end

  defp client do
    Tesla.client(
      [
        {Tesla.Middleware.BaseUrl, config()[:base_url]},
        Tesla.Middleware.JSON,
        {Tesla.Middleware.BearerAuth, token: config()[:api_key]},
        {Tesla.Middleware.Retry,
         delay: 1_000,
         max_delay: 2_000,
         max_retries: 30,
         should_retry: fn
           {:error, :timeout} -> true
           {:error, :checkout_timeout} -> true
           {:error, :checkout_failure} -> true
           _else -> false
         end},
        {Tesla.Middleware.Retry,
         delay: 60_000,
         jitter_factor: 0.0,
         max_delay: 60_000,
         max_retries: 5,
         should_retry: fn
           {:ok, %{status: 429}} -> true
           {:ok, %{status: 502}} -> true
           _else -> false
         end}
      ],
      Tesla.Adapter.Hackney
    )
  end

  defp handle_response({:ok, %{status: code, body: body}}) when code in 200..299 do
    {:ok, body}
  end

  defp handle_response({:ok, %{status: code}}) when code == 404 do
    Logger.warning("Contact not found in Faraday.")

    {:error, :not_found}
  end

  defp handle_response({:ok, %{status: code}}) when code == 401 do
    Logger.warning("Unauthorized request to Faraday.")

    {:error, :unauthorized}
  end

  defp handle_response({:ok, response}) do
    Logger.warning("Unexpected Response from Faraday", details: inspect(response))

    {:error, :unexpected_response}
  end

  defp handle_response({:error, response}) do
    Logger.warning("Unexpected Error Response from Faraday", details: inspect(response))

    {:error, :unexpected_error}
  end
end
