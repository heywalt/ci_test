defmodule WaltUi.Enrichment.JitterJob do
  @moduledoc """
  Coordinator job that runs weekly to enqueue jitter batches.

  Selects 25% of enrichments randomly and distributes them across
  batch workers to prevent EventStore overwhelm.
  """
  use Oban.Worker, queue: :jitter, max_attempts: 1

  import Ecto.Query

  require Logger

  alias WaltUi.Enrichment.JitterBatchWorker
  alias WaltUi.Projections.Enrichment

  @batch_size 100
  @oban_insert_batch_size 50

  @impl Oban.Worker
  def perform(_job) do
    enrichment_count = Repo.aggregate(Enrichment, :count)
    limit = ceil(enrichment_count / 4)

    Logger.info("Starting jitter coordinator",
      total_enrichments: enrichment_count,
      to_jitter: limit
    )

    {:ok, batch_count} =
      Repo.transaction(fn ->
        enrichments_to_jitter_query(limit)
        |> Repo.stream()
        |> Stream.chunk_every(@batch_size)
        |> Stream.chunk_every(@oban_insert_batch_size)
        |> Stream.map(&enqueue_batch_jobs/1)
        |> Enum.sum()
      end)

    Logger.info("Jitter coordinator complete", batches_enqueued: batch_count)

    :ok
  end

  defp enrichments_to_jitter_query(limit) do
    from enrich in Enrichment,
      order_by: fragment("RANDOM()"),
      limit: ^limit,
      select: enrich.id
  end

  defp enqueue_batch_jobs(enrichment_id_chunks) do
    jobs =
      Enum.map(enrichment_id_chunks, fn enrichment_ids ->
        JitterBatchWorker.new(%{enrichment_ids: enrichment_ids})
      end)

    case Oban.insert_all(jobs) do
      {count, _} -> count
      _ -> 0
    end
  end
end
