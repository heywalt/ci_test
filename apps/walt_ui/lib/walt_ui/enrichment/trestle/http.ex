defmodule WaltUi.Enrichment.Trestle.Http do
  @moduledoc """
  HTTP Client for interacting with the Trestle API.
  """
  require Logger

  alias WaltUi.Error

  @spec search_by_phone(String.t(), Keyword.t()) :: {:ok, map()} | {:error, atom()}
  def search_by_phone(phone, opts \\ []) do
    query_params = build_query_params(phone, opts)

    client()
    |> Tesla.get("/3.2/phone", query: query_params)
    |> handle_response()
  end

  defp build_query_params(phone, opts) do
    params = [phone: phone]

    case Keyword.get(opts, :name_hint) do
      nil -> params
      name_hint -> params ++ ["phone.name_hint": name_hint]
    end
  end

  defp config do
    Application.get_env(:walt_ui, WaltUi.Trestle)
  end

  defp client do
    Tesla.client(
      [
        {Tesla.Middleware.BaseUrl, config()[:base_url] || "https://api.trestleiq.com"},
        Tesla.Middleware.JSON,
        {Tesla.Middleware.Headers,
         [
           {"accept", "application/json"},
           {"x-api-key", config()[:api_key]}
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
         delay: 1_000,
         max_delay: 6_000,
         max_retries: 10,
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

  defp handle_response({:ok, %{status: 404}}) do
    Error.new("Phone number not found", reason_atom: :not_found)
  end

  defp handle_response({:ok, %{status: 401}}) do
    Error.new("Unauthorized request to Trestle", reason_atom: :unauthorized)
  end

  defp handle_response({:ok, %{status: 400}}) do
    Error.new("Malformed request to Trestle", reason_atom: :bad_request)
  end

  defp handle_response({:ok, response}) do
    Error.new("Unexpected Response from Trestle",
      reason_atom: :unexpected_response,
      details: response
    )
  end

  defp handle_response({:error, response}) do
    Error.new("Unexpected Error from Trestle", reason_atom: :unexpected_error, details: response)
  end
end
