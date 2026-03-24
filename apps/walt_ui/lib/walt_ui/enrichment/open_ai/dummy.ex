defmodule WaltUi.Enrichment.OpenAi.Dummy do
  @moduledoc """
  Dummy implementation of the OpenAi behaviour, for use when manually testing Enrichment locally
  when you don't want to make real requests to the OpenAi API.
  """
  @behaviour WaltUi.Enrichment.OpenAi

  @impl true
  def confirm_identity(_possible_match, _identity) do
    simulate_request_response()
    {:ok, true}
  end

  @impl true
  def contact_matches_data(_contact, _data) do
    simulate_request_response()
    {:ok, true}
  end

  defp simulate_request_response do
    20..300
    |> Enum.random()
    |> Process.sleep()
  end
end
