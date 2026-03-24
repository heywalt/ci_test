defmodule WaltUi.Google.Gmail.HistoricalSyncMonitor do
  @moduledoc """
  Monitoring and administrative helper functions for historical email sync.
  Provides visibility into sync status, progress, and stats across users.
  """
  import Ecto.Query

  alias WaltUi.ExternalAccounts.ExternalAccount

  @doc """
  Gets the sync status and progress for a specific external account.
  """
  @spec get_sync_status(String.t()) ::
          %{
            external_account_id: String.t(),
            email: String.t() | nil,
            status: String.t(),
            progress: map() | nil,
            started_at: DateTime.t() | nil,
            completed_at: DateTime.t() | nil,
            duration_seconds: integer() | nil,
            error: map() | nil
          }
          | nil
  def get_sync_status(external_account_id) do
    case Repo.get(ExternalAccount, external_account_id) do
      nil ->
        nil

      ea ->
        metadata = ea.historical_sync_metadata || %{}

        %{
          external_account_id: ea.id,
          email: ea.email,
          status: metadata["status"] || "not_started",
          progress: metadata["progress"],
          started_at: parse_datetime(metadata["started_at"]),
          completed_at: parse_datetime(metadata["completed_at"]),
          duration_seconds: calculate_duration(metadata),
          error: metadata["error"]
        }
    end
  end

  @doc """
  Lists all external accounts with active (in_progress) historical syncs.
  """
  @spec list_active_syncs() :: [map()]
  def list_active_syncs do
    query =
      from ea in ExternalAccount,
        where: ea.provider == :google,
        where: fragment("?->>'status' = 'in_progress'", ea.historical_sync_metadata),
        order_by: [desc: fragment("?->>'started_at'", ea.historical_sync_metadata)],
        select: %{
          external_account_id: ea.id,
          user_id: ea.user_id,
          email: ea.email,
          status: fragment("?->>'status'", ea.historical_sync_metadata),
          started_at: fragment("?->>'started_at'", ea.historical_sync_metadata),
          last_updated_at: fragment("?->>'last_updated_at'", ea.historical_sync_metadata),
          progress: fragment("?->'progress'", ea.historical_sync_metadata)
        }

    Repo.all(query)
  end

  @doc """
  Lists all external accounts that have attempted historical sync, with their status.
  """
  @spec list_all_sync_attempts(keyword()) :: [map()]
  def list_all_sync_attempts(opts \\ []) do
    limit = Keyword.get(opts, :limit, 50)
    status_filter = Keyword.get(opts, :status)

    query =
      from ea in ExternalAccount,
        where: ea.provider == :google,
        where: not is_nil(ea.historical_sync_metadata),
        order_by: [desc: fragment("?->>'started_at'", ea.historical_sync_metadata)],
        limit: ^limit,
        select: %{
          external_account_id: ea.id,
          user_id: ea.user_id,
          email: ea.email,
          status: fragment("?->>'status'", ea.historical_sync_metadata),
          started_at: fragment("?->>'started_at'", ea.historical_sync_metadata),
          completed_at: fragment("?->>'completed_at'", ea.historical_sync_metadata),
          last_updated_at: fragment("?->>'last_updated_at'", ea.historical_sync_metadata),
          progress: fragment("?->'progress'", ea.historical_sync_metadata),
          error: fragment("?->'error'", ea.historical_sync_metadata)
        }

    query =
      if status_filter do
        from [ea] in query,
          where: fragment("?->>'status' = ?", ea.historical_sync_metadata, ^status_filter)
      else
        query
      end

    Repo.all(query)
  end

  @doc """
  Gets aggregated statistics about historical syncs.
  """
  @spec get_sync_statistics() :: %{
          total_attempts: integer(),
          completed: integer(),
          failed: integer(),
          in_progress: integer(),
          not_started: integer(),
          average_duration_seconds: float() | nil,
          success_rate: float()
        }
  def get_sync_statistics do
    stats_query =
      from ea in ExternalAccount,
        where: ea.provider == :google,
        select: %{
          total_google_accounts: count(ea.id),
          attempted_syncs: count(ea.id, :distinct),
          completed:
            fragment(
              "COUNT(CASE WHEN ?->>'status' = 'success' THEN 1 END)",
              ea.historical_sync_metadata
            ),
          failed:
            fragment(
              "COUNT(CASE WHEN ?->>'status' = 'failed' THEN 1 END)",
              ea.historical_sync_metadata
            ),
          in_progress:
            fragment(
              "COUNT(CASE WHEN ?->>'status' = 'in_progress' THEN 1 END)",
              ea.historical_sync_metadata
            ),
          avg_duration:
            fragment(
              """
              AVG(
                CASE 
                  WHEN ?->>'status' IN ('success', 'failed') 
                       AND ?->>'started_at' IS NOT NULL 
                       AND ?->>'completed_at' IS NOT NULL
                  THEN 
                    EXTRACT(EPOCH FROM (
                      (?->>'completed_at')::timestamp - (?->>'started_at')::timestamp
                    ))
                  ELSE NULL
                END
              )
              """,
              ea.historical_sync_metadata,
              ea.historical_sync_metadata,
              ea.historical_sync_metadata,
              ea.historical_sync_metadata,
              ea.historical_sync_metadata
            )
        },
        where: not is_nil(ea.historical_sync_metadata)

    result = Repo.one(stats_query) || %{}

    total_attempts = result[:attempted_syncs] || 0
    completed = result[:completed] || 0
    failed = result[:failed] || 0
    in_progress = result[:in_progress] || 0

    # Count accounts that haven't attempted sync
    not_started_query =
      from ea in ExternalAccount,
        where: ea.provider == :google,
        where: is_nil(ea.historical_sync_metadata),
        select: count(ea.id)

    not_started = Repo.one(not_started_query) || 0

    success_rate =
      if total_attempts > 0 do
        completed / total_attempts * 100
      else
        0.0
      end

    %{
      total_attempts: total_attempts,
      completed: completed,
      failed: failed,
      in_progress: in_progress,
      not_started: not_started,
      average_duration_seconds: result[:avg_duration],
      success_rate: success_rate
    }
  end

  @doc """
  Gets detailed sync information for a specific user.
  """
  @spec get_user_sync_status(String.t()) :: [map()]
  def get_user_sync_status(user_id) do
    query =
      from ea in ExternalAccount,
        where: ea.user_id == ^user_id,
        where: ea.provider == :google,
        select: %{
          external_account_id: ea.id,
          email: ea.email,
          status:
            fragment(
              "COALESCE(?->>'status', 'not_started')",
              ea.historical_sync_metadata
            ),
          started_at: fragment("?->>'started_at'", ea.historical_sync_metadata),
          completed_at: fragment("?->>'completed_at'", ea.historical_sync_metadata),
          last_updated_at: fragment("?->>'last_updated_at'", ea.historical_sync_metadata),
          progress: fragment("?->'progress'", ea.historical_sync_metadata),
          error: fragment("?->'error'", ea.historical_sync_metadata)
        }

    Repo.all(query)
  end

  @doc """
  Finds external accounts that have been stuck in 'in_progress' status for too long.
  Default threshold is 2 hours.
  """
  @spec find_stuck_syncs(integer()) :: [map()]
  def find_stuck_syncs(hours_threshold \\ 2) do
    threshold_time = DateTime.utc_now() |> DateTime.add(-hours_threshold, :hour)

    query =
      from ea in ExternalAccount,
        where: ea.provider == :google,
        where: fragment("?->>'status' = 'in_progress'", ea.historical_sync_metadata),
        where:
          fragment(
            "(?->>'last_updated_at')::timestamp < ?",
            ea.historical_sync_metadata,
            ^threshold_time
          ),
        select: %{
          external_account_id: ea.id,
          user_id: ea.user_id,
          email: ea.email,
          started_at: fragment("?->>'started_at'", ea.historical_sync_metadata),
          last_updated_at: fragment("?->>'last_updated_at'", ea.historical_sync_metadata),
          hours_stuck:
            fragment(
              "EXTRACT(EPOCH FROM (NOW() - (?->>'last_updated_at')::timestamp)) / 3600",
              ea.historical_sync_metadata
            )
        }

    Repo.all(query)
  end

  @doc """
  Resets the sync status for a stuck external account to allow retry.
  """
  @spec reset_sync_status(String.t()) :: {:ok, ExternalAccount.t()} | {:error, any()}
  def reset_sync_status(external_account_id) do
    case Repo.get(ExternalAccount, external_account_id) do
      nil ->
        {:error, :not_found}

      ea ->
        reset_metadata = %{
          status: "not_started",
          reset_at: DateTime.utc_now(),
          reset_reason: "Manual reset via monitor"
        }

        WaltUi.ExternalAccounts.update(ea, %{historical_sync_metadata: reset_metadata})
    end
  end

  @doc """
  Pretty prints sync statistics for console/admin use.
  """
  @spec print_sync_summary() :: :ok
  def print_sync_summary do
    stats = get_sync_statistics()

    IO.puts("\n=== Historical Email Sync Statistics ===")
    IO.puts("Total sync attempts: #{stats.total_attempts}")
    IO.puts("✅ Completed: #{stats.completed}")
    IO.puts("❌ Failed: #{stats.failed}")
    IO.puts("🔄 In progress: #{stats.in_progress}")
    IO.puts("⏸️  Not started: #{stats.not_started}")
    IO.puts("📊 Success rate: #{Float.round(stats.success_rate, 1)}%")

    if stats.average_duration_seconds do
      avg_minutes = stats.average_duration_seconds / 60
      IO.puts("⏱️  Average duration: #{Float.round(avg_minutes, 1)} minutes")
    end

    active_syncs = list_active_syncs()

    if length(active_syncs) > 0 do
      IO.puts("\n=== Active Syncs ===")

      for sync <- active_syncs do
        IO.puts("#{sync.email} - Started: #{sync.started_at}")
      end
    end

    stuck_syncs = find_stuck_syncs()

    if length(stuck_syncs) > 0 do
      IO.puts("\n⚠️  === Stuck Syncs (>2 hours) ===")

      for sync <- stuck_syncs do
        IO.puts("#{sync.email} - Stuck for #{Float.round(sync.hours_stuck, 1)} hours")
      end
    end

    IO.puts("")
    :ok
  end

  defp parse_datetime(nil), do: nil

  defp parse_datetime(datetime_string) when is_binary(datetime_string) do
    case DateTime.from_iso8601(datetime_string) do
      {:ok, datetime, _} -> datetime
      _ -> nil
    end
  end

  defp parse_datetime(%DateTime{} = datetime), do: datetime
  defp parse_datetime(_), do: nil

  defp calculate_duration(%{"started_at" => started, "completed_at" => completed})
       when is_binary(started) and is_binary(completed) do
    with {:ok, start_dt, _} <- DateTime.from_iso8601(started),
         {:ok, end_dt, _} <- DateTime.from_iso8601(completed) do
      DateTime.diff(end_dt, start_dt)
    else
      _ -> nil
    end
  end

  defp calculate_duration(_), do: nil
end
