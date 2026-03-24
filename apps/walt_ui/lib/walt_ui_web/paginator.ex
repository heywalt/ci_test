defmodule WaltUiWeb.Paginator do
  @moduledoc """
  Page based pagination strategy
  """

  @behaviour JSONAPI.Paginator

  @impl true
  # def paginate(data, view, conn, nil, options) do
  #   paginate(data, view, conn, %{}, options)
  # end

  def paginate(data, view, %{assigns: %{paginate: pagination}} = conn, _page, _options) do
    %{page_number: number, page_size: page_size, total_pages: total_pages} = pagination

    %{
      first: view.url_for_pagination(data, conn, %{number: "1", size: page_size}),
      last: view.url_for_pagination(data, conn, %{number: total_pages, size: page_size}),
      next: next_link(data, view, conn, number, page_size, total_pages),
      prev: previous_link(data, view, conn, number, page_size)
    }
  end

  def paginate(_data, _view, _conn, _page, _options) do
    %{
      first: nil,
      last: nil,
      next: nil,
      prev: nil
    }
  end

  defp next_link(data, view, conn, page, size, total_pages) when page < total_pages do
    view.url_for_pagination(data, conn, %{size: size, number: page + 1})
  end

  defp next_link(_data, _view, _conn, _page, _size, _total_pages),
    do: nil

  defp previous_link(data, view, conn, page, size) when page > 1 do
    view.url_for_pagination(data, conn, %{size: size, number: page - 1})
  end

  defp previous_link(_data, _view, _conn, _page, _size),
    do: nil
end
