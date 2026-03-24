defmodule WaltUi.Email.SyncContactEmailsJob do
  @moduledoc """
  Oban job to sync email messages for specific email addresses on contact updates.
  Fetches messages to/from the specified email addresses for the configured historical sync period.
  Reuses the existing historical sync infrastructure for consistency.
  """
  use Oban.Worker,
    queue: :contact_email_sync,
    max_attempts: 3,
    priority: 3

  require Logger

  alias WaltUi.ExternalAccounts
  alias WaltUi.ExternalAccounts.ExternalAccount
  alias WaltUi.Google.Gmail
  alias WaltUi.Google.Gmail.HistoricalSync.MessageProcessor
  alias WaltUi.Google.Gmail.HistoricalSync.QueryBuilder

  @impl Oban.Worker
  def perform(%Oban.Job{
        args: %{"external_account_id" => ea_id, "email_addresses" => email_addresses}
      }) do
    Logger.metadata(
      oban_job: "sync_contact_emails",
      external_account_id: ea_id,
      email_addresses: email_addresses
    )

    Logger.info("Starting contact email sync job",
      email_addresses: email_addresses,
      sync_days: QueryBuilder.get_days_back()
    )

    with {:ok, external_account} <- get_google_external_account(ea_id),
         :ok <- sync_messages_for_addresses(external_account, email_addresses) do
      Logger.info("Contact email sync completed successfully")
      :ok
    else
      {:error, :not_found} ->
        Logger.error("External account not found", external_account_id: ea_id)
        {:error, "External account not found"}

      {:error, reason} ->
        Logger.error("Contact email sync failed",
          external_account_id: ea_id,
          error: inspect(reason)
        )

        {:error, reason}
    end
  end

  # Catch-all for debugging
  def perform(%Oban.Job{args: args} = job) do
    Logger.error("SyncContactEmailsJob called with unexpected args structure",
      args: inspect(args),
      job: inspect(job)
    )

    {:error, "Unexpected args structure"}
  end

  defp get_google_external_account(ea_id) do
    case ExternalAccounts.get(ea_id) do
      nil -> {:error, :not_found}
      %ExternalAccount{provider: :google} = ea -> {:ok, ea}
      _ -> {:error, :not_google}
    end
  end

  defp sync_messages_for_addresses(external_account, email_addresses) do
    valid_addresses = get_valid_addresses(email_addresses)

    if Enum.empty?(valid_addresses) do
      Logger.info("No valid email addresses to sync")
      :ok
    else
      fetch_and_process_messages(external_account, valid_addresses)
    end
  end

  defp get_valid_addresses(email_addresses) do
    email_addresses
    |> Enum.reject(&(is_nil(&1) or &1 == ""))
    |> Enum.uniq()
  end

  defp fetch_and_process_messages(external_account, valid_addresses) do
    sync_query = QueryBuilder.build_contact_query(valid_addresses, external_account.email)

    Logger.info("Built Gmail query for addresses",
      query: sync_query,
      address_count: length(valid_addresses)
    )

    with {:ok, message_ids} <- fetch_all_messages(external_account, sync_query) do
      process_fetched_messages(external_account, message_ids)
    end
  end

  defp process_fetched_messages(external_account, message_ids) do
    Logger.info("Found #{length(message_ids)} messages to process")

    if length(message_ids) > 0 do
      MessageProcessor.process_all(external_account, message_ids)
    else
      Logger.info("No messages found for query")
      :ok
    end
  end

  defp fetch_all_messages(external_account, query) do
    fetch_messages_paginated(external_account, query, [])
  end

  defp fetch_messages_paginated(external_account, query, acc, page_token \\ "") do
    opts = build_request_opts(query, page_token)

    case Gmail.list_message_ids(external_account, opts) do
      {:ok, response} -> handle_response(external_account, query, response, acc)
      {:error, reason} -> {:error, reason}
    end
  end

  defp build_request_opts(query, "") do
    [query: query]
  end

  defp build_request_opts(query, page_token) do
    [query: query, page_token: page_token]
  end

  defp handle_response(external_account, query, response, acc) do
    message_ids = extract_message_ids(response)
    new_acc = acc ++ message_ids

    case response["nextPageToken"] do
      nil -> {:ok, new_acc}
      next_token -> fetch_messages_paginated(external_account, query, new_acc, next_token)
    end
  end

  defp extract_message_ids(%{"messages" => messages}) when is_list(messages) do
    Enum.map(messages, & &1["id"])
  end

  defp extract_message_ids(_), do: []
end
