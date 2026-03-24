defmodule WaltUi.Providers.WebSearch do
  @moduledoc """
  Web search provider using Google Custom Search API.

  ## Configuration

  Add to your config:

      config :walt_ui, :google_custom_search,
        api_key: System.get_env("GOOGLE_API_KEY"),
        search_engine_id: System.get_env("GOOGLE_CUSTOM_SEARCH_ENGINE_ID")

  ## Setup Instructions

  1. Enable Custom Search API in Google Cloud Console for your existing API key
  2. Create a Programmable Search Engine at https://programmablesearchengine.google.com/
  3. Set GOOGLE_CUSTOM_SEARCH_ENGINE_ID environment variable

  ## Pricing

  - First 100 queries/day: FREE
  - Beyond 100: $5 per 1,000 queries
  """

  require Logger

  @doc """
  Search the web and return formatted results.

  ## Examples

      iex> search("current mortgage rates", 5)
      {:ok, %{
        query: "current mortgage rates",
        results: [
          %{
            title: "Mortgage Rates Today",
            snippet: "30-year fixed mortgage rates...",
            url: "https://example.com/rates"
          }
        ]
      }}
  """
  def search(query, num_results \\ 5) do
    config = Application.get_env(:walt_ui, :google_custom_search, [])
    api_key = Keyword.get(config, :api_key)
    search_engine_id = Keyword.get(config, :search_engine_id)

    cond do
      is_nil(api_key) or api_key == "" ->
        {:error, "Google Custom Search API key not configured"}

      is_nil(search_engine_id) or search_engine_id == "" ->
        {:error, "Google Custom Search Engine ID not configured"}

      true ->
        perform_search(query, num_results, api_key, search_engine_id)
    end
  end

  defp perform_search(query, num_results, api_key, search_engine_id) do
    client = build_client()

    params = [
      key: api_key,
      cx: search_engine_id,
      q: query,
      num: min(num_results, 10)
    ]

    case Tesla.get(client, "/customsearch/v1", query: params) do
      {:ok, %{status: 200, body: body}} ->
        parse_results(query, body)

      {:ok, %{status: status, body: body}} ->
        Logger.error("Google Custom Search API error: #{status} - #{inspect(body)}")
        {:error, "Search failed with status #{status}"}

      {:error, reason} ->
        Logger.error("Google Custom Search request failed: #{inspect(reason)}")
        {:error, "Search request failed"}
    end
  end

  defp build_client do
    middleware = [
      {Tesla.Middleware.BaseUrl, "https://www.googleapis.com"},
      Tesla.Middleware.JSON,
      {Tesla.Middleware.Retry,
       delay: 500,
       max_retries: 2,
       max_delay: 2_000,
       should_retry: fn
         {:ok, %{status: 429}} -> true
         {:ok, %{status: status}} when status >= 500 -> true
         {:error, _} -> true
         _ -> false
       end}
    ]

    adapter = Application.get_env(:tesla, :adapter, Tesla.Adapter.Hackney)
    Tesla.client(middleware, adapter)
  end

  defp parse_results(query, body) do
    results =
      body
      |> Map.get("items", [])
      |> Enum.map(fn item ->
        %{
          title: Map.get(item, "title"),
          snippet: Map.get(item, "snippet"),
          url: Map.get(item, "link")
        }
      end)

    {:ok,
     %{
       query: query,
       results: results,
       total_results: get_in(body, ["searchInformation", "totalResults"]),
       search_time: get_in(body, ["searchInformation", "searchTime"])
     }}
  end
end
