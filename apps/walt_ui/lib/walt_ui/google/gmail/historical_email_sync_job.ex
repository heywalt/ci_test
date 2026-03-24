defmodule WaltUi.Google.Gmail.HistoricalEmailSyncJob do
  @moduledoc """
  Oban job to sync historical email messages for a newly authorized Google account.
  Fetches messages to/from contacts and creates ContactInteractions.
  """
  use Oban.Worker,
    queue: :historical_email_sync,
    max_attempts: 3,
    priority: 2,
    unique: [
      period: :infinity,
      fields: [:args, :queue],
      keys: [:external_account_id],
      states: [:scheduled, :available, :executing, :retryable]
    ]

  require Logger

  alias WaltUi.ExternalAccounts
  alias WaltUi.ExternalAccounts.ExternalAccount
  alias WaltUi.Google.Gmail.HistoricalSync

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"external_account_id" => ea_id}}) do
    Logger.metadata(
      oban_job: "historical_email_sync",
      external_account_id: ea_id
    )

    Logger.info("Starting historical email sync job")

    with {:ok, external_account} <- get_external_account(ea_id),
         :ok <- validate_google_provider(external_account),
         :ok <- HistoricalSync.sync_historical_messages(external_account) do
      Logger.info("Historical email sync completed successfully")
      :ok
    else
      {:error, :not_found} ->
        Logger.error("External account not found", external_account_id: ea_id)
        {:error, "External account not found"}

      {:error, :not_google} ->
        Logger.warning("Skipping historical sync for non-Google provider",
          external_account_id: ea_id
        )

        :ok

      {:error, reason} ->
        Logger.error("Historical email sync failed",
          external_account_id: ea_id,
          error: inspect(reason)
        )

        {:error, reason}
    end
  end

  defp get_external_account(ea_id) do
    case ExternalAccounts.get(ea_id) do
      nil -> {:error, :not_found}
      ea -> {:ok, ea}
    end
  end

  defp validate_google_provider(%ExternalAccount{provider: :google}), do: :ok
  defp validate_google_provider(_), do: {:error, :not_google}
end
