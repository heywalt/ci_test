defmodule WaltUi.Enrichment.EnrichmentCronJob do
  @moduledoc """
  Find user contacts without enrichment and re-attempt enrichment. This job should
  run on a cron schedule, once a month at most.
  """
  use Oban.Worker, max_attempts: 5, queue: :enrichment

  import Ecto.Query

  alias WaltUi.Enrichment.EnrichmentJob

  @impl true
  def perform(_job) do
    stream =
      unenriched_contacts_query()
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

  defp unenriched_contacts_query do
    from c in WaltUi.Projections.Contact,
      distinct: c.standard_phone,
      where: is_nil(c.enrichment_id),
      select: %{
        email: c.email,
        first_name: c.first_name,
        last_name: c.last_name,
        phone: c.standard_phone
      }
  end
end
