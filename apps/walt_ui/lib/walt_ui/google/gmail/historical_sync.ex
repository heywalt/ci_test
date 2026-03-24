defmodule WaltUi.Google.Gmail.HistoricalSync do
  @moduledoc """
  Orchestrates syncing of historical email messages for newly authorized Google accounts.
  Coordinates between message processing, progress tracking, and query building components.
  """
  require Logger

  alias WaltUi.Contacts
  alias WaltUi.ExternalAccounts
  alias WaltUi.ExternalAccounts.ExternalAccount
  alias WaltUi.Google.Gmail
  alias WaltUi.Google.Gmail.HistoricalSync.MessageProcessor
  alias WaltUi.Google.Gmail.HistoricalSync.ProgressTracker
  alias WaltUi.Google.Gmail.HistoricalSync.QueryBuilder

  # Maximum number of emails per Gmail query to avoid query length limits
  @emails_per_query 50

  @doc """
  Main entry point for syncing historical messages.
  """
  @spec sync_historical_messages(ExternalAccount.t()) :: :ok | {:error, any()}
  def sync_historical_messages(external_account) do
    Logger.metadata(
      external_account_id: external_account.id,
      user_id: external_account.user_id,
      email: external_account.email,
      sync_type: :historical_email,
      sync_id: Ecto.UUID.generate()
    )

    Logger.info("Starting historical email sync", email: external_account.email)

    with :ok <- start_sync(external_account),
         :ok <- sync_messages_for_contacts_chunked(external_account) do
      finalize_sync(external_account, :success)
    else
      {:error, reason} = error ->
        log_sync_failure(external_account, reason)
        finalize_sync(external_account, :failed, reason)
        error
    end
  end

  defp start_sync(external_account) do
    now = DateTime.utc_now()

    # Log existing metadata before reset
    fresh_ea = ExternalAccounts.get(external_account.id)

    if fresh_ea.historical_sync_metadata do
      Logger.info("Previous sync metadata exists",
        previous_status: fresh_ea.historical_sync_metadata["status"],
        previous_progress: inspect(fresh_ea.historical_sync_metadata["progress"])
      )
    end

    # Create fresh metadata, completely replacing any previous sync data
    metadata = %{
      "status" => "in_progress",
      "started_at" => now,
      "last_updated_at" => now,
      "progress" => %{
        "messages_processed" => 0,
        "interactions_created" => 0,
        "duplicates_skipped" => 0,
        "batch_number" => 0
      }
    }

    Logger.metadata(status: "in_progress")

    # Force update with completely new metadata
    {:ok, updated_ea} = ExternalAccounts.update(fresh_ea, %{historical_sync_metadata: metadata})

    Logger.info("Sync started with fresh metadata",
      progress: inspect(updated_ea.historical_sync_metadata["progress"])
    )

    :ok
  end

  defp sync_messages_for_contacts_chunked(external_account) do
    user_id = external_account.user_id
    total_contacts = Contacts.count_contacts_with_emails(user_id)
    chunk_size = calculate_chunk_size(total_contacts)

    log_chunked_processing_start(total_contacts, chunk_size)

    case total_contacts do
      0 -> handle_empty_contact_list(external_account)
      count -> process_contact_chunks(external_account, count, chunk_size)
    end
  end

  defp log_chunked_processing_start(total_contacts, chunk_size) do
    Logger.info("Starting chunked contact processing",
      total_contacts: total_contacts,
      chunk_size: chunk_size,
      adaptive_sizing:
        chunk_size != Application.get_env(:walt_ui, :historical_sync)[:contacts_chunk_size]
    )
  end

  defp handle_empty_contact_list(external_account) do
    Logger.info("No contacts with emails found for user")

    update_sync_progress(external_account, :contacts_chunked, %{
      total_contacts: 0,
      total_chunks: 0,
      current_chunk: 0,
      contacts_processed: 0
    })

    :ok
  end

  defp process_contact_chunks(external_account, total_contacts, chunk_size) do
    total_chunks = div(total_contacts + chunk_size - 1, chunk_size)

    Logger.info("Will process in chunks", total_chunks: total_chunks)

    update_sync_progress(external_account, :contacts_chunked, %{
      total_contacts: total_contacts,
      total_chunks: total_chunks,
      current_chunk: 0,
      contacts_processed: 0
    })

    {successful_chunks, failed_chunks} =
      execute_chunk_processing(external_account, total_chunks, chunk_size, total_contacts)

    log_chunk_completion(successful_chunks, failed_chunks, total_chunks)
    evaluate_chunk_results(successful_chunks, total_chunks)
  end

  defp execute_chunk_processing(external_account, total_chunks, chunk_size, total_contacts) do
    0..(total_chunks - 1)
    |> Enum.reduce({0, []}, fn chunk_index, {successful, failed} ->
      case process_contact_chunk_safely(external_account, chunk_index, chunk_size, total_contacts) do
        :ok ->
          {successful + 1, failed}

        {:error, error} ->
          handle_chunk_failure(external_account, chunk_index, error, {successful, failed})
      end
    end)
  end

  defp handle_chunk_failure(external_account, chunk_index, error, {successful, failed}) do
    Logger.warning("Chunk processing failed, continuing with next chunk",
      chunk: chunk_index + 1,
      error: inspect(error)
    )

    record_failed_chunk(external_account, chunk_index, error)
    {successful, [chunk_index | failed]}
  end

  defp log_chunk_completion(successful_chunks, failed_chunks, total_chunks) do
    Logger.info("Chunk processing completed",
      successful_chunks: successful_chunks,
      failed_chunks: length(failed_chunks),
      total_chunks: total_chunks
    )
  end

  defp evaluate_chunk_results(successful_chunks, total_chunks) do
    case {successful_chunks, total_chunks} do
      {0, 0} -> :ok
      {count, _} when count > 0 -> :ok
      {0, _} -> {:error, "All chunks failed to process"}
    end
  end

  defp process_contact_chunk_safely(external_account, chunk_index, chunk_size, total_contacts) do
    offset = chunk_index * chunk_size
    contacts_in_chunk = min(chunk_size, total_contacts - offset)

    try do
      process_contact_chunk(external_account, chunk_index, chunk_size, total_contacts)
    rescue
      error ->
        error_type = Exception.message(error)

        Logger.error("Contact chunk processing failed with exception: #{error_type}
  Chunk: #{chunk_index + 1} (contacts #{offset + 1}-#{offset + contacts_in_chunk})
  External account: #{external_account.email} (#{external_account.id})
  Error: #{inspect(error)}
  Stacktrace: #{Exception.format_stacktrace(__STACKTRACE__)}")

        {:error, error}
    catch
      :exit, reason ->
        Logger.error("Contact chunk processing exited unexpectedly
  Chunk: #{chunk_index + 1} (contacts #{offset + 1}-#{offset + contacts_in_chunk})
  External account: #{external_account.email} (#{external_account.id})
  Exit reason: #{inspect(reason)}")

        {:error, {:exit, reason}}

      kind, reason ->
        Logger.error("Contact chunk processing failed with #{kind}
  Chunk: #{chunk_index + 1} (contacts #{offset + 1}-#{offset + contacts_in_chunk})
  External account: #{external_account.email} (#{external_account.id})
  Reason: #{inspect(reason)}")

        {:error, {kind, reason}}
    end
  end

  defp process_contact_chunk(external_account, chunk_index, chunk_size, total_contacts) do
    offset = chunk_index * chunk_size
    user_id = external_account.user_id

    Logger.info("Processing contact chunk",
      chunk: chunk_index + 1,
      offset: offset,
      chunk_size: chunk_size
    )

    with_timing("process_contact_chunk_#{chunk_index + 1}", fn ->
      # Load emails for this chunk
      chunk_emails = Contacts.get_emails_for_contact_chunk(user_id, offset, chunk_size)

      Logger.info("Loaded emails for chunk",
        chunk: chunk_index + 1,
        emails_count: length(chunk_emails)
      )

      # Process Gmail sync for this chunk
      result = sync_messages_for_email_list(external_account, chunk_emails)

      # Update progress
      contacts_in_chunk = min(chunk_size, total_contacts - offset)
      update_chunk_progress(external_account, chunk_index + 1, contacts_in_chunk)

      # Force garbage collection to free chunk memory
      :erlang.garbage_collect()

      # Monitor memory usage after chunk processing
      monitor_memory_usage(chunk_index + 1)

      result
    end)
  end

  defp calculate_chunk_size(total_contacts) do
    base_chunk_size = Application.get_env(:walt_ui, :historical_sync)[:contacts_chunk_size]
    max_contacts_limit = Application.get_env(:walt_ui, :historical_sync)[:max_contacts_in_memory]

    cond do
      total_contacts == 0 ->
        base_chunk_size

      total_contacts <= 1000 ->
        # Small users: process all at once for efficiency
        min(total_contacts, base_chunk_size)

      total_contacts <= 10_000 ->
        # Medium users: use base chunk size
        base_chunk_size

      total_contacts <= 50_000 ->
        # Large users: increase chunk size for efficiency
        min(base_chunk_size * 2, max_contacts_limit)

      true ->
        # Very large users: use maximum safe chunk size
        max_contacts_limit
    end
  end

  defp monitor_memory_usage(chunk_number) do
    memory_mb = :erlang.memory(:total) / (1024 * 1024)
    rounded_memory = Float.round(memory_mb, 2)

    Logger.info("Memory usage after chunk processing",
      chunk: chunk_number,
      memory_mb: rounded_memory
    )

    if memory_mb > 500 do
      Logger.warning("High memory usage detected during historical sync",
        memory_mb: rounded_memory,
        chunk: chunk_number
      )
    end

    memory_mb
  end

  defp record_failed_chunk(external_account, chunk_index, error) do
    fresh_ea = ExternalAccounts.get(external_account.id)
    current_metadata = fresh_ea.historical_sync_metadata || %{}
    failed_chunks = Map.get(current_metadata, "failed_chunks", [])

    failure_record = %{
      chunk_index: chunk_index,
      error: inspect(error),
      timestamp: DateTime.utc_now()
    }

    updated_metadata =
      Map.put(current_metadata, "failed_chunks", [failure_record | failed_chunks])

    ExternalAccounts.update(fresh_ea, %{
      historical_sync_metadata: updated_metadata
    })
  end

  defp sync_messages_for_email_list(external_account, emails) do
    # Use existing chunking logic but for smaller email lists
    emails
    |> Enum.chunk_every(@emails_per_query)
    |> Enum.with_index(1)
    |> Enum.reduce_while(:ok, fn {email_batch, batch_index}, _acc ->
      case sync_email_batch(external_account, email_batch, batch_index, length(emails)) do
        :ok -> {:cont, :ok}
        {:error, _} = error -> {:halt, error}
      end
    end)
  end

  defp sync_email_batch(external_account, email_batch, batch_index, total_emails) do
    # Calculate total batches using ceiling division to round up for any remainder
    # div(total_emails + @emails_per_query - 1, @emails_per_query) ensures we count
    # partial batches (e.g., 101 emails / 50 per batch = 3 batches, not 2)
    total_batches = div(total_emails + @emails_per_query - 1, @emails_per_query)

    Logger.info(
      "Processing contact email batch #{batch_index}/#{total_batches} with #{length(email_batch)} email addresses"
    )

    query = QueryBuilder.build_contact_query(email_batch, external_account.email)

    with {:ok, messages} <- fetch_all_messages(external_account, query),
         :ok <- MessageProcessor.process_all(external_account, messages) do
      Logger.info(
        "Successfully processed email batch #{batch_index}/#{total_batches}: found #{length(messages)} messages"
      )

      :ok
    else
      {:error, reason} = error ->
        sample_emails = email_batch |> Enum.take(3) |> Enum.join(", ")
        remaining = length(email_batch) - 3

        email_preview =
          if remaining > 0, do: "#{sample_emails}, and #{remaining} more", else: sample_emails

        Logger.error(
          "Failed to process email batch #{batch_index}/#{total_batches}: #{inspect(reason)}
  Email addresses in batch: #{email_preview}
  Query length: #{String.length(query)} chars"
        )

        error
    end
  end

  defp fetch_all_messages(external_account, query, page_token \\ "", accumulated_messages \\ []) do
    # Log query_length for troubleshooting - if queries fail due to length limits,
    # this helps determine if @emails_per_query should be reduced from 50
    Logger.info("Fetching messages from Gmail",
      query_length: String.length(query),
      has_page_token: page_token != ""
    )

    case Gmail.list_message_ids(external_account, query: query, page_token: page_token) do
      {:ok, response} ->
        handle_gmail_response(external_account, query, response, accumulated_messages)

      {:error, reason} = error ->
        Logger.error("Failed to fetch message IDs", error: inspect(reason))
        error
    end
  end

  defp handle_gmail_response(
         external_account,
         query,
         %{"messages" => messages} = response,
         accumulated_messages
       )
       when is_list(messages) do
    message_ids = Enum.map(messages, & &1["id"])

    Logger.info("Retrieved message IDs",
      count: length(message_ids),
      total_so_far: length(accumulated_messages) + length(message_ids)
    )

    new_accumulated = accumulated_messages ++ message_ids

    handle_pagination(external_account, query, response, new_accumulated)
  end

  defp handle_gmail_response(_external_account, _query, %{}, accumulated_messages) do
    Logger.info("No messages found for query")
    {:ok, accumulated_messages}
  end

  defp handle_pagination(external_account, query, response, accumulated_messages) do
    case Map.get(response, "nextPageToken") do
      nil ->
        {:ok, accumulated_messages}

      next_token ->
        fetch_all_messages(external_account, query, next_token, accumulated_messages)
    end
  end

  defp finalize_sync(external_account, status, error \\ nil) do
    # Reload to get latest metadata
    fresh_ea = ExternalAccounts.get(external_account.id)
    current_metadata = fresh_ea.historical_sync_metadata || %{}

    error_data =
      if error do
        %{message: inspect(error), timestamp: DateTime.utc_now()}
      else
        nil
      end

    final_metadata =
      current_metadata
      |> Map.put("status", to_string(status))
      |> Map.put("completed_at", DateTime.utc_now())
      |> Map.put("last_updated_at", DateTime.utc_now())
      |> Map.put("error", error_data)
      |> Enum.reject(fn {_k, v} -> is_nil(v) end)
      |> Enum.into(%{})

    Logger.metadata(status: to_string(status))

    {:ok, updated_ea} =
      ExternalAccounts.update(fresh_ea, %{historical_sync_metadata: final_metadata})

    # Log the metadata before getting final stats
    Logger.debug("Final metadata before stats calculation",
      metadata: inspect(updated_ea.historical_sync_metadata)
    )

    # Get final stats and log summary using the returned updated EA
    stats = ProgressTracker.get_final_stats(updated_ea)

    Logger.debug("Final stats extracted",
      stats: inspect(stats)
    )

    log_final_summary(external_account, status, stats)

    :ok
  end

  defp log_sync_failure(external_account, reason) do
    Logger.error("Historical sync failed",
      external_account_id: external_account.id,
      email: external_account.email,
      error: inspect(reason)
    )
  end

  defp update_sync_progress(external_account, phase, progress_data) do
    # Get existing metadata to preserve MessageProcessor progress tracking
    fresh_ea = ExternalAccounts.get(external_account.id)
    current_metadata = fresh_ea.historical_sync_metadata || %{}

    # Merge chunked progress data with existing progress
    existing_progress = Map.get(current_metadata, "progress", %{})
    merged_progress = Map.merge(existing_progress, progress_data)

    updated_metadata =
      Map.merge(current_metadata, %{
        "status" => "in_progress",
        "phase" => phase,
        "progress" => merged_progress,
        "last_updated_at" => DateTime.utc_now()
      })

    ExternalAccounts.update(fresh_ea, %{
      historical_sync_metadata: updated_metadata
    })
  end

  defp update_chunk_progress(external_account, completed_chunks, contacts_in_chunk) do
    fresh_ea = ExternalAccounts.get(external_account.id)
    current_metadata = fresh_ea.historical_sync_metadata || %{}
    current_progress = Map.get(current_metadata, "progress", %{})

    new_progress =
      Map.merge(current_progress, %{
        "current_chunk" => completed_chunks,
        "contacts_processed" =>
          Map.get(current_progress, "contacts_processed", 0) + contacts_in_chunk
      })

    updated_metadata = Map.put(current_metadata, "progress", new_progress)
    updated_metadata = Map.put(updated_metadata, "last_updated_at", DateTime.utc_now())

    ExternalAccounts.update(fresh_ea, %{
      historical_sync_metadata: updated_metadata
    })
  end

  defp with_timing(operation_name, fun) do
    start_time = System.monotonic_time(:millisecond)
    result = fun.()
    duration = System.monotonic_time(:millisecond) - start_time

    Logger.info("Historical sync operation completed",
      operation: operation_name,
      duration_ms: duration
    )

    result
  end

  defp log_final_summary(external_account, status, stats) do
    summary_stats = [
      status: status,
      messages_processed: stats.messages_processed,
      duration_seconds: stats.duration_seconds,
      email: external_account.email
    ]

    summary =
      "Historical sync completed " <>
        Enum.map_join(summary_stats, " ", fn {k, v} -> "#{k}=#{v}" end)

    Logger.info(summary)
  end
end
