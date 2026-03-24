defmodule WaltUi.Enrichment.Faraday.Dummy do
  @moduledoc """
  Dummy implementation of the Faraday behaviour, for use when manually testing Enrichment locally
  when you don't want to make real requests to the Faraday API.
  """
  @behaviour WaltUi.Enrichment.Faraday

  @impl true
  def fetch_by_identity_sets(_list) do
    {:ok, %{value: "This is a dummy response"}}
  end

  @impl true
  def fetch_contact(_contact) do
    simulate_request_response()

    {:ok, %{value: "This is a dummy response"}}
  end

  @impl true
  def extract_ptt(_response) do
    simulate_request_response()

    {:ok, "This is a dummy response"}
  end

  defp simulate_request_response do
    20..300
    |> Enum.random()
    |> Process.sleep()
  end
end
