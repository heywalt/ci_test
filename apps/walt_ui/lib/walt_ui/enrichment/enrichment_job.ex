defmodule WaltUi.Enrichment.EnrichmentJob do
  @moduledoc """
  This job is started by the `EnrichmentCronJob` or `ReEnrichmentCronJob`.
  """
  use Oban.Worker, max_attempts: 3, queue: :enrichment

  alias CQRS.Enrichments.Commands.RequestEnrichment

  @impl true
  def perform(%{args: %{"data" => data}}) do
    Enum.each(data, fn attrs ->
      attrs
      |> atom_keys()
      |> RequestEnrichment.new()
      |> CQRS.dispatch()
    end)
  end

  defp atom_keys(attrs) do
    for {k, v} <- attrs, do: {String.to_atom(k), v}, into: %{}
  end
end
