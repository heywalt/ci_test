defmodule WaltUi.Enrichment.Endato.Http do
  @moduledoc """
  HTTP Client for interacting with the Endato API.
  """
  require Logger

  alias WaltUi.Error

  @spec fetch_contact(map()) :: {:ok, map()} | {:error, atom()}
  def fetch_contact(request) do
    [search_type: "DevAPIContactEnrich"]
    |> client()
    |> Tesla.post("/Contact/Enrich", request)
    |> handle_response()
  end

  @spec search_by_phone(String.t()) :: {:ok, any} | {:error, atom()}
  def search_by_phone(phone) do
    [search_type: "DevAPICallerID"]
    |> client()
    |> Tesla.post("/Phone/Enrich", %{Phone: phone})
    |> handle_response()
  end

  defp config do
    Application.get_env(:walt_ui, WaltUi.Endato)
  end

  defp client(opts) do
    search_type = Keyword.get(opts, :search_type, nil)

    Tesla.client(
      [
        {Tesla.Middleware.BaseUrl, config()[:base_url]},
        Tesla.Middleware.JSON,
        {Tesla.Middleware.Headers,
         [
           "galaxy-ap-name": config()[:api_id],
           "galaxy-ap-password": config()[:api_key],
           "galaxy-search-type": search_type
         ]},
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
         delay: 60_000,
         jitter_factor: 0.0,
         max_delay: 60_000,
         max_retries: 5,
         should_retry: fn
           {:ok, %{status: 429}} -> true
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
    Error.new("Contact not found", reason_atom: :not_found)
  end

  defp handle_response({:ok, %{status: code}}) when code == 401 do
    Error.new("Unauthorized request to Endato", reason_atom: :unauthorized)
  end

  defp handle_response({:ok, %{status: code}}) when code == 400 do
    Error.new("Malformed request to Endato", reason_atom: :bad_request)
  end

  defp handle_response({:ok, response}) do
    Error.new("Unexpected Response from Endato",
      reason_atom: :unexpected_response,
      details: response
    )
  end

  defp handle_response({:error, response}) do
    Error.new("Unexpected Error from Endato", reason_atom: :unexpected_error, details: response)
  end
end
