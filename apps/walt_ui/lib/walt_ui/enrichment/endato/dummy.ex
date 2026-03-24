defmodule WaltUi.Enrichment.Endato.Dummy do
  @moduledoc """
  Dummy implementation of the Endato behaviour, for use when manually testing Enrichment locally
  when you don't want to make real requests to the Endato API.
  """
  @behaviour WaltUi.Enrichment.Endato

  @impl true
  def fetch_contact(_contact) do
    simulate_request_response()

    {:ok, %{value: "This is a dummy response"}}
  end

  @impl true
  def search_by_phone(_phone) do
    simulate_request_response()

    {:ok, %{value: "This is a dummy response"}}
  end

  defp simulate_request_response do
    20..300
    |> Enum.random()
    |> Process.sleep()
  end
end
