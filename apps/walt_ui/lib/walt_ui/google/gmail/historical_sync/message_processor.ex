defmodule WaltUi.Google.Gmail.HistoricalSync.MessageProcessor do
  @moduledoc """
  Handles processing of email messages during historical sync.
  Responsible for fetching, formatting, and creating ContactInteractions.
  """
  require Logger

  alias WaltUi.ExternalAccounts.ExternalAccount
  alias WaltUi.Google.Gmail
  alias WaltUi.Google.Gmail.HistoricalSync.ProgressTracker

  @messages_per_batch 50

  @doc """
  Processes all messages for a given external account.
  """
  @spec process_all(ExternalAccount.t(), list(String.t())) :: :ok
  def process_all(external_account, message_ids) do
    Logger.info("Processing messages", total_messages: length(message_ids))

    message_ids
    |> Enum.chunk_every(@messages_per_batch)
    |> Enum.with_index(1)
    |> Enum.each(fn {batch, batch_num} ->
      with_timing("process_message_batch_#{batch_num}", fn ->
        {:ok, {processed, duplicates, batch_message_count}} =
          process_batch(external_account, batch, batch_num)

        # Notify progress tracker
        ProgressTracker.update_batch_progress(
          external_account,
          batch_message_count,
          processed,
          duplicates,
          batch_num
        )
      end)
    end)

    :ok
  end

  @doc """
  Processes a batch of message IDs, fetching full details and creating interactions.
  """
  @spec process_batch(ExternalAccount.t(), list(String.t()), integer()) ::
          {:ok, {integer(), integer(), integer()}}
  def process_batch(external_account, message_ids, batch_num) do
    batch_start = System.monotonic_time(:millisecond)

    Logger.info("Processing message batch #{batch_num} with #{length(message_ids)} messages")

    # Time message fetching
    fetch_start = System.monotonic_time(:millisecond)
    messages = fetch_messages(external_account, message_ids)
    fetch_duration = System.monotonic_time(:millisecond) - fetch_start

    Logger.info("Fetched #{length(messages)} messages in #{fetch_duration}ms")

    # Time message preparation
    prep_start = System.monotonic_time(:millisecond)
    processed_messages = prepare_messages(messages, external_account)
    prep_duration = System.monotonic_time(:millisecond) - prep_start

    filter_ratio =
      if(length(messages) > 0,
        do: Float.round(length(processed_messages) / length(messages), 2),
        else: 0.0
      )

    Logger.info(
      "Message preparation complete: #{length(messages)} -> #{length(processed_messages)} messages (#{filter_ratio} retention rate) in #{prep_duration}ms"
    )

    # Time interaction creation
    interaction_start = System.monotonic_time(:millisecond)
    {processed_count, duplicate_count} = create_interactions(processed_messages)
    interaction_duration = System.monotonic_time(:millisecond) - interaction_start

    batch_duration = System.monotonic_time(:millisecond) - batch_start

    Logger.info(
      "Batch #{batch_num} complete: #{processed_count} new, #{duplicate_count} duplicates in #{batch_duration}ms total (fetch: #{fetch_duration}ms, prep: #{prep_duration}ms, create: #{interaction_duration}ms)"
    )

    {:ok, {processed_count, duplicate_count, length(processed_messages)}}
  end

  # Private functions

  defp fetch_messages(external_account, message_ids) do
    start_time = System.monotonic_time(:millisecond)
    total_messages = length(message_ids)

    Logger.info("Starting to fetch #{total_messages} messages")

    {fetched_messages, failed_count} =
      message_ids
      |> Enum.with_index(1)
      |> Enum.reduce({[], 0}, fn {message_id, index}, {acc_messages, acc_failed} ->
        fetch_single_message(
          external_account,
          message_id,
          index,
          total_messages,
          {acc_messages, acc_failed}
        )
      end)

    total_duration = System.monotonic_time(:millisecond) - start_time
    avg_duration = if(total_messages > 0, do: div(total_duration, total_messages), else: 0)

    Logger.info(
      "Completed fetching messages: #{length(fetched_messages)}/#{total_messages} successful, #{failed_count} failed, #{total_duration}ms total (#{avg_duration}ms avg)"
    )

    fetched_messages
    |> Enum.reverse()
    |> Enum.map(&Gmail.format_message/1)
  end

  defp fetch_single_message(
         external_account,
         message_id,
         index,
         total_messages,
         {acc_messages, acc_failed}
       ) do
    fetch_start = System.monotonic_time(:millisecond)

    case Gmail.get_message(external_account, message_id) do
      {:ok, body} ->
        maybe_warn_slow_fetch(fetch_start, index, total_messages)
        {[body | acc_messages], acc_failed}

      {:error, error} ->
        fetch_duration = System.monotonic_time(:millisecond) - fetch_start
        error_info = format_error_info(error)

        Logger.error(
          "Failed to fetch message #{index}/#{total_messages} after #{fetch_duration}ms: #{error_info}"
        )

        {acc_messages, acc_failed + 1}
    end
  end

  defp maybe_warn_slow_fetch(fetch_start, index, total_messages) do
    fetch_duration = System.monotonic_time(:millisecond) - fetch_start

    if fetch_duration > 1000 do
      Logger.warning("Slow message fetch: #{index}/#{total_messages} took #{fetch_duration}ms")
    end
  end

  defp format_error_info({:error, %{status: 401}}), do: "Unauthorized (401)"
  defp format_error_info({:error, %{status: 403}}), do: "Forbidden (403)"
  defp format_error_info({:error, %{status: 404}}), do: "Not found (404)"
  defp format_error_info({:error, %{status: 429}}), do: "Rate limited (429)"

  defp format_error_info({:error, %{status: status}}) when status >= 500,
    do: "Server error (#{status})"

  defp format_error_info({:error, :timeout}), do: "Request timeout"
  defp format_error_info({:error, :closed}), do: "Connection closed"
  defp format_error_info(error), do: inspect(error)

  defp prepare_messages(messages, external_account) do
    messages
    |> Gmail.categorize_messages(external_account.email)
    |> Gmail.filter_messages_with_contacts(external_account)
    |> Enum.map(&format_date/1)
    |> Enum.reject(&is_nil/1)
    |> Enum.map(&Map.merge(&1, %{source: "google", user_id: external_account.user_id}))
    |> Enum.map(&add_message_link/1)
  end

  defp format_date(message) do
    # Delegate to Gmail module's robust date parsing
    Gmail.format_date(message)
  end

  defp add_message_link(message) do
    Map.put(message, :message_link, "https://mail.google.com/mail/u/#all/#{message.id}")
  end

  defp create_interactions(messages) do
    Enum.reduce(messages, {0, 0}, fn message, {processed, duplicates} ->
      process_single_message(message, {processed, duplicates})
    end)
  end

  defp process_single_message(message, {processed, duplicates}) do
    case extract_all_contact_ids(message) do
      [] ->
        {processed, duplicates}

      contact_ids ->
        message
        |> Map.put(:contact_ids, contact_ids)
        |> create_correspondence_event({processed, duplicates})
    end
  end

  defp extract_all_contact_ids(message) do
    case message[:contact_ids] do
      ids when is_list(ids) ->
        ids
        # Keep only valid string IDs
        |> Enum.filter(&is_binary/1)
        # Remove duplicates
        |> Enum.uniq()

      id when is_binary(id) ->
        [id]

      _ ->
        []
    end
  end

  defp create_correspondence_event(message, {processed, duplicates}) do
    # The message already contains all contact_ids - CQRS will handle each contact
    result = CQRS.create_correspondence(message)

    case result do
      results when is_list(results) ->
        {new_events, duplicate_count} = count_cqrs_results(results)
        {processed + new_events, duplicates + duplicate_count}

      {:error, error} ->
        log_creation_failure(message, error)
        {processed, duplicates}

      other ->
        log_unexpected_result(message, other)
        {processed, duplicates}
    end
  end

  defp count_cqrs_results(results) do
    # Log what we're processing
    Logger.debug("Counting CQRS results",
      total_results: length(results),
      first_result: List.first(results) |> inspect()
    )

    counts =
      Enum.reduce(results, {0, 0}, fn result, {new_events, duplicates} ->
        case result do
          {:ok, %CQRS.Leads.LeadAggregate{}} ->
            {new_events + 1, duplicates}

          :ok ->
            {new_events, duplicates + 1}

          {:error, _} ->
            {new_events, duplicates}

          other ->
            Logger.warning("Unexpected CQRS result in count_cqrs_results",
              result: inspect(other)
            )

            {new_events, duplicates}
        end
      end)

    Logger.debug("CQRS count results",
      new_events: elem(counts, 0),
      duplicates: elem(counts, 1)
    )

    counts
  end

  # Logging helpers

  defp log_creation_failure(message, error) do
    Logger.warning(
      "Failed to create ContactCorresponded event: message_id=#{message.id} error=#{inspect(error)}"
    )
  end

  defp log_unexpected_result(message, result) do
    Logger.warning("Unexpected CQRS result: message_id=#{message.id} result=#{inspect(result)}")
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
end
