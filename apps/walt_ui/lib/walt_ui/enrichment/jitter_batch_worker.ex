defmodule WaltUi.Enrichment.JitterBatchWorker do
  @moduledoc """
  Worker that processes a batch of enrichment IDs for jittering.

  Part of the distributed jitter system that prevents EventStore overwhelm
  by processing enrichments in controlled batches rather than all at once.
  """
  use Oban.Worker,
    queue: :jitter,
    max_attempts: 3

  require Logger

  alias CQRS.Enrichments.Commands.Jitter

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"enrichment_ids" => enrichment_ids}}) do
    Logger.info("Processing jitter batch", count: length(enrichment_ids))

    results =
      enrichment_ids
      |> Enum.map(&to_command/1)
      |> Enum.map(&dispatch_with_result/1)

    failures = Enum.count(results, &match?({:error, _}, &1))

    if failures > 0 do
      Logger.warning("Jitter batch completed with failures",
        total: length(enrichment_ids),
        failures: failures
      )
    end

    :ok
  end

  defp to_command(id) do
    %Jitter{
      id: id,
      timestamp: NaiveDateTime.truncate(NaiveDateTime.utc_now(), :second)
    }
  end

  defp dispatch_with_result(command) do
    case CQRS.dispatch(command) do
      :ok ->
        :ok

      {:ok, _} ->
        :ok

      {:error, reason} = error ->
        Logger.warning("Failed to dispatch Jitter command",
          enrichment_id: command.id,
          reason: inspect(reason)
        )

        error
    end
  end
end
