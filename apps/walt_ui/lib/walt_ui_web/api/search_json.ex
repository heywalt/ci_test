defmodule WaltUiWeb.Api.SearchJSON do
  @doc """
  Renders the results of the search.
  """

  def index(%{results: results}) do
    results
  end
end
