defmodule WaltUi.Google.Gmail.HistoricalSync.ProgressTracker do
  @moduledoc """
  Handles progress tracking for historical sync operations.
  Only manages progress metrics, not sync orchestration.
  """
  require Logger

  alias WaltUi.ExternalAccounts
  alias WaltUi.ExternalAccounts.ExternalAccount

  @doc """
  Creates initial progress structure for metadata.
  Does not perform database operations - just returns the structure.
  """
  @spec initial_progress() :: map()
  def initial_progress do
    %{
      messages_processed: 0,
      interactions_created: 0,
      duplicates_skipped: 0,
      batch_number: 0
    }
  end

  @doc """
  Updates progress after processing a message batch.
  """
  @spec update_batch_progress(ExternalAccount.t(), integer(), integer(), integer(), integer()) ::
          :ok
  def update_batch_progress(
        external_account,
        messages_processed,
        interactions_created,
        duplicates_skipped,
        batch_number
      ) do
    # Reload to get latest metadata
    fresh_ea = ExternalAccounts.get(external_account.id)
    current_metadata = normalize_metadata(fresh_ea.historical_sync_metadata || %{})

    # Update cumulative progress
    current_progress = current_metadata.progress

    new_progress = %{
      messages_processed: current_progress.messages_processed + messages_processed,
      interactions_created: current_progress.interactions_created + interactions_created,
      duplicates_skipped: current_progress.duplicates_skipped + duplicates_skipped,
      batch_number: batch_number
    }

    updated_metadata = %{
      current_metadata
      | progress: new_progress,
        last_updated_at: DateTime.utc_now()
    }

    ExternalAccounts.update(external_account, %{historical_sync_metadata: updated_metadata})

    Logger.info("Historical sync progress: #{format_progress(new_progress)}")
    :ok
  end

  @doc """
  Gets final progress statistics for completion logging.
  """
  @spec get_final_stats(ExternalAccount.t()) :: map()
  def get_final_stats(external_account) do
    metadata = normalize_metadata(external_account.historical_sync_metadata || %{})
    progress = metadata.progress
    duration = calculate_duration(metadata)

    %{
      messages_processed: progress.messages_processed,
      interactions_created: progress.interactions_created,
      duplicates_skipped: progress.duplicates_skipped,
      duration_seconds: duration
    }
  end

  # Private functions

  # Normalizes metadata to use atom keys consistently
  defp normalize_metadata(metadata) do
    %{
      status: get_field(metadata, :status),
      started_at: parse_datetime(get_field(metadata, :started_at)),
      completed_at: parse_datetime(get_field(metadata, :completed_at)),
      last_updated_at: parse_datetime(get_field(metadata, :last_updated_at)),
      error: get_field(metadata, :error),
      progress: normalize_progress(get_field(metadata, :progress) || %{})
    }
  end

  defp normalize_progress(progress) do
    %{
      messages_processed: get_integer_field(progress, :messages_processed),
      interactions_created: get_integer_field(progress, :interactions_created),
      duplicates_skipped: get_integer_field(progress, :duplicates_skipped),
      batch_number: get_integer_field(progress, :batch_number)
    }
  end

  defp get_field(map, field) do
    Map.get(map, field) || Map.get(map, to_string(field))
  end

  defp get_integer_field(map, field) do
    case get_field(map, field) do
      n when is_integer(n) -> n
      n when is_binary(n) -> String.to_integer(n)
      _ -> 0
    end
  end

  defp parse_datetime(%DateTime{} = dt), do: dt
  defp parse_datetime(nil), do: nil

  defp parse_datetime(str) when is_binary(str) do
    case DateTime.from_iso8601(str) do
      {:ok, dt, _} -> dt
      _ -> nil
    end
  end

  defp parse_datetime(_), do: nil

  defp format_progress(progress) do
    [
      "messages_processed=#{progress.messages_processed}",
      "interactions_created=#{progress.interactions_created}",
      "duplicates_skipped=#{progress.duplicates_skipped}",
      "batch_number=#{progress.batch_number}"
    ]
    |> Enum.join(" ")
  end

  defp calculate_duration(metadata) do
    case {metadata.started_at, metadata.completed_at} do
      {%DateTime{} = start, %DateTime{} = complete} ->
        DateTime.diff(complete, start)

      _ ->
        0
    end
  end
end
