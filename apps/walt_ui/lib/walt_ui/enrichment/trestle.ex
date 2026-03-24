defmodule WaltUi.Enrichment.Trestle do
  @moduledoc """
  Behaviour for Trestle, defining the callbacks required to interact with the Trestle API.
  """

  @callback search_by_phone(String.t(), Keyword.t()) :: {:ok, map()} | {:error, String.t()}

  @spec search_by_phone(String.t(), Keyword.t()) :: {:ok, map()} | {:error, String.t()}
  def search_by_phone(phone, opts \\ []) do
    client().search_by_phone(phone, opts)
  end

  defp client do
    Application.get_env(:walt_ui, WaltUi.Trestle)[:client] || WaltUi.Enrichment.Trestle.Client
  end
end
