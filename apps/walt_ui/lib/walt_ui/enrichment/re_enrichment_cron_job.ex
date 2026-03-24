defmodule WaltUi.Enrichment.ReEnrichmentCronJob do
  @moduledoc """
  Find Faraday enrichments that have not been updated in over 30 days and request re-enrichment.
  """
  use Oban.Worker, max_attempts: 5, queue: :enrichment

  import Ecto.Query

  alias WaltUi.Enrichment.EnrichmentJob

  @impl true
  def perform(_job) do
    stream =
      stale_faraday_data()
      |> Repo.stream()
      |> Stream.chunk_every(100)

    Repo.transaction(fn ->
      Enum.reduce(stream, 0, fn chunk, acc ->
        %{"data" => chunk}
        |> EnrichmentJob.new(schedule_in: acc)
        |> Oban.insert()

        acc + 5
      end)
    end)
  end

  defp stale_faraday_data do
    from f in WaltUi.Projections.Faraday,
      where: fragment("(CURRENT_DATE() - ?::date) > 30", f.updated_at),
      select: %{
        id: f.id,
        email: f.email,
        first_name: f.first_name,
        last_name: f.last_name,
        phone: f.phone
      }
  end
end
