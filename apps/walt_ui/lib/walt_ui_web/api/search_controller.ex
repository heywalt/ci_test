defmodule WaltUiWeb.Api.SearchController do
  use WaltUiWeb, :controller

  require Logger

  alias CQRS.Utils
  alias WaltUi.Search

  action_fallback WaltUiWeb.FallbackController

  def index(conn, %{"query" => query} = params) do
    current_user = conn.assigns.current_user
    opts = get_pagination_opts(params)
    contacts = Search.search_all_by_user(current_user.id, query, opts)

    Logger.info("Search returned #{length(contacts)} contacts",
      details: query,
      user_id: current_user.id
    )

    conn
    |> put_view(WaltUiWeb.Api.ContactsView)
    |> render(:show, %{data: contacts})
  end

  def new_index(conn, params) do
    current_user = conn.assigns.current_user
    query = get_query(params)
    pagination_opts = get_pagination_opts(params)
    filter_by_opts = get_filter_by_opts(params)
    order_by_opts = get_order_by_opts(params)
    location_opts = get_location_opts(params)
    opts = pagination_opts ++ filter_by_opts ++ order_by_opts ++ location_opts

    search_results = Search.new_search_all_by_user(current_user.id, query, opts)

    Logger.info("Search returned #{length(search_results.hits)} contacts",
      details: query,
      user_id: current_user.id
    )

    json(conn, %{data: search_results})
  end

  defp get_query(query) do
    query
    |> Map.get("query")
    |> case do
      nil ->
        "*"

      "" ->
        "*"

      query ->
        query
    end
  end

  defp get_pagination_opts(%{"page" => page_opts}) do
    [page: Map.get(page_opts, "page", 1), per_page: Map.get(page_opts, "size", 30)]
  end

  defp get_pagination_opts(_params), do: []

  defp get_filter_by_opts(%{"filter_by" => filter_by}) do
    case Jason.decode(filter_by) do
      {:ok, filter_by} ->
        filter_by
        |> Enum.map(&Utils.atom_map/1)
        |> then(&[filter_by: &1])

      {:error, _} ->
        []
    end
  end

  defp get_filter_by_opts(_params), do: []

  defp get_order_by_opts(%{"order_by" => order_by}) do
    case Jason.decode(order_by) do
      {:ok, order_by} ->
        order_by
        |> Enum.map(&Utils.atom_map/1)
        |> then(&[order_by: &1])

      {:error, _} ->
        []
    end
  end

  defp get_order_by_opts(_params), do: []

  defp get_location_opts(params) do
    # Check if all required location params are present
    lat = Map.get(params, "latitude")
    lng = Map.get(params, "longitude")
    distance = Map.get(params, "distance")

    if lat && lng && distance do
      with {lat_float, _} <- Float.parse(lat),
           {lng_float, _} <- Float.parse(lng),
           {distance_num, _} <- Float.parse(distance) do
        [location: {lat_float, lng_float, "#{distance_num} mi"}]
      else
        _ -> []
      end
    else
      []
    end
  end
end
