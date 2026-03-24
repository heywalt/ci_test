defmodule WaltUi.Google.Maps.Http do
  @moduledoc """
  HTTP Client for interacting with the Google Maps Geocoding API.
  """
  require Logger

  @spec geocode_address(String.t()) :: {:ok, map()} | {:error, atom()}
  def geocode_address(address_string) do
    query_params = [
      address: address_string,
      key: config()[:api_key]
    ]

    client()
    |> Tesla.get("/geocode/json", query: query_params)
    |> handle_response()
  end

  defp config do
    Application.get_env(:walt_ui, :google_maps)
  end

  defp client do
    Tesla.client(
      [
        {Tesla.Middleware.BaseUrl, "https://maps.googleapis.com/maps/api"},
        Tesla.Middleware.JSON,
        {Tesla.Middleware.Retry,
         delay: 500,
         max_delay: 1_000,
         max_retries: 10,
         should_retry: fn
           {:error, :timeout} -> true
           {:error, :checkout_timeout} -> true
           _else -> false
         end},
        {Tesla.Middleware.Retry,
         delay: 1_000,
         max_delay: 6_000,
         max_retries: 10,
         should_retry: fn
           {:ok, %{status: 429}} -> true
           {:ok, %{status: 500}} -> true
           {:ok, %{status: 502}} -> true
           {:ok, %{status: 503}} -> true
           _else -> false
         end}
      ],
      Tesla.Adapter.Hackney
    )
  end

  defp handle_response({:ok, %{status: code, body: body}}) when code in 200..299 do
    case body do
      %{"status" => "OK", "results" => [result | _]} ->
        extract_coordinates(result)

      %{"status" => "ZERO_RESULTS"} ->
        {:error, :zero_results}

      %{"status" => "OVER_QUERY_LIMIT"} ->
        {:error, :quota_exceeded}

      %{"status" => "REQUEST_DENIED"} ->
        Logger.warning("Google Maps API request denied")
        {:error, :request_denied}

      %{"status" => "INVALID_REQUEST"} ->
        Logger.warning("Invalid request to Google Maps API")
        {:error, :invalid_request}

      %{"status" => status} ->
        Logger.warning("Google Maps API returned status: #{status}")
        {:error, :api_error}

      _ ->
        Logger.warning("Unexpected response format from Google Maps API")
        {:error, :invalid_response}
    end
  end

  defp handle_response({:ok, %{status: 429}}) do
    Logger.warning("Rate limit exceeded for Google Maps API")
    {:error, :rate_limit_exceeded}
  end

  defp handle_response({:ok, %{status: code}}) do
    Logger.warning("Google Maps API returned status #{code}")
    {:error, :api_error}
  end

  defp handle_response({:error, response}) do
    Logger.error("Google Maps API request failed: #{inspect(response)}")
    {:error, :network_error}
  end

  defp extract_coordinates(%{"geometry" => %{"location" => %{"lat" => lat, "lng" => lng}}}) do
    {:ok, {lat, lng}}
  end

  defp extract_coordinates(_) do
    Logger.warning("Could not extract coordinates from Google Maps API response")
    {:error, :invalid_response}
  end
end
