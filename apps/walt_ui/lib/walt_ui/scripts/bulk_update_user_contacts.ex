defmodule WaltUi.Scripts.BulkUpdateUserContacts do
  @moduledoc """
  Bulk update TypeSense documents for all contacts belonging to a specific user.

  This module efficiently handles updating 4000+ contacts by:
  - Streaming contacts from the database to minimize memory usage
  - Formatting contacts for TypeSense compatibility
  - Batch processing with configurable batch sizes
  - Comprehensive error handling and progress tracking

  ## Usage

      # Update all contacts for a user with default settings
      WaltUi.Scripts.BulkUpdateUserContacts.update_all_for_user(user_id)

      # Update with custom batch size
      WaltUi.Scripts.BulkUpdateUserContacts.update_all_for_user(user_id, batch_size: 200)
  """

  require Logger
  import Ecto.Query

  alias WaltUi.ContactTags
  alias WaltUi.Projections.Contact
  alias WaltUi.Projections.Jitter

  @default_batch_size 500
  @default_timeout :infinity

  @doc """
  Updates all TypeSense documents for a given user's contacts.

  ## Options
    * `:batch_size` - Number of documents per TypeSense request (default: 500)
    * `:progress_callback` - Function called with (processed_count, total_count) after each batch

  ## Returns
    * `{:ok, %{total: integer, successful: integer, failed: integer, errors: list}}`
    * `{:error, reason}`
  """
  @spec update_all_for_user(Ecto.UUID.t(), keyword()) ::
          {:ok, map()} | {:error, any()}
  def update_all_for_user(user_id, opts \\ []) do
    batch_size = Keyword.get(opts, :batch_size, @default_batch_size)
    progress_callback = Keyword.get(opts, :progress_callback, &default_progress_callback/2)

    Logger.info("Starting bulk TypeSense update for user #{user_id}")
    Logger.info("Batch size: #{batch_size}")

    # First, get total count for progress tracking
    total_count = get_contact_count(user_id)
    Logger.info("Found #{total_count} contacts to update")

    if total_count == 0 do
      {:ok, %{total: 0, successful: 0, failed: 0, errors: []}}
    else
      result =
        Repo.transaction(
          fn ->
            process_contacts_in_batches(user_id, batch_size, progress_callback, total_count)
          end,
          timeout: @default_timeout
        )

      case result do
        {:ok, stats} ->
          Logger.info("Bulk update completed: #{inspect(stats)}")
          {:ok, stats}

        {:error, reason} = error ->
          Logger.error("Bulk update failed: #{inspect(reason)}")
          error
      end
    end
  end

  @doc """
  Updates TypeSense documents for a specific list of contact IDs.

  Useful for selective updates or retry logic.
  """
  @spec update_contacts_by_ids(Ecto.UUID.t(), [Ecto.UUID.t()], keyword()) ::
          {:ok, map()} | {:error, any()}
  def update_contacts_by_ids(user_id, contact_ids, opts \\ []) do
    batch_size = Keyword.get(opts, :batch_size, @default_batch_size)

    contacts =
      Contact
      |> where([c], c.user_id == ^user_id)
      |> where([c], c.id in ^contact_ids)
      |> Repo.all()

    formatted_docs = Enum.map(contacts, &format_for_typesense/1)

    formatted_docs
    |> Enum.chunk_every(batch_size)
    |> Enum.reduce(%{total: 0, successful: 0, failed: 0, errors: []}, fn batch, acc ->
      process_batch(batch, acc)
    end)
    |> then(&{:ok, &1})
  end

  def bulk_update_jittered_contacts(opts \\ []) do
    batch_size = Keyword.get(opts, :batch_size, @default_batch_size)

    three_days_ago = DateTime.utc_now() |> DateTime.add(-3, :day)

    q =
      from(c in Contact,
        join: j in Jitter,
        on: j.id == c.enrichment_id,
        where: j.inserted_at >= ^three_days_ago,
        select: %{c | ptt: j.ptt}
      )

    contacts = Repo.all(q)

    formatted_docs = Enum.map(contacts, &format_for_typesense/1)

    formatted_docs
    |> Enum.chunk_every(batch_size)
    |> Enum.reduce(%{total: 0, successful: 0, failed: 0, errors: []}, fn batch, acc ->
      process_batch(batch, acc)
    end)
    |> then(&{:ok, &1})
  end

  # Private functions

  defp get_contact_count(user_id) do
    Contact
    |> where([c], c.user_id == ^user_id)
    |> Repo.aggregate(:count, :id)
  end

  defp process_contacts_in_batches(user_id, batch_size, progress_callback, total_count) do
    user_id
    |> stream_user_contacts()
    |> Stream.map(&format_for_typesense/1)
    |> Stream.chunk_every(batch_size)
    |> Stream.with_index()
    |> Enum.reduce(%{total: 0, successful: 0, failed: 0, errors: []}, fn {batch, batch_index},
                                                                         acc ->
      Logger.info("Processing batch #{batch_index + 1} with #{length(batch)} documents")
      new_acc = process_batch(batch, acc)
      progress_callback.(new_acc.total, total_count)
      new_acc
    end)
  end

  defp stream_user_contacts(user_id) do
    Contact
    |> where([c], c.user_id == ^user_id)
    |> order_by([c], asc: c.inserted_at)
    |> Repo.stream()
  end

  defp process_batch(batch, acc) do
    batch_size = length(batch)

    case ExTypesense.import_documents("contacts", batch, action: "upsert", batch_size: batch_size) do
      {:ok, results} ->
        # Parse results to count successes and failures
        {successful, failed, errors} = parse_import_results(results)

        %{
          total: acc.total + batch_size,
          successful: acc.successful + successful,
          failed: acc.failed + failed,
          errors: acc.errors ++ errors
        }

      {:error, error} ->
        Logger.error("Batch import failed: #{inspect(error)}")

        %{
          total: acc.total + batch_size,
          successful: acc.successful,
          failed: acc.failed + batch_size,
          errors: acc.errors ++ [%{batch_size: batch_size, error: error}]
        }
    end
  end

  defp parse_import_results(results) when is_list(results) do
    Enum.reduce(results, {0, 0, []}, fn result, {success_count, fail_count, errors} ->
      case result do
        %{"success" => true} ->
          {success_count + 1, fail_count, errors}

        %{"success" => false} = failure ->
          error_info = Map.take(failure, ["error", "document"])
          {success_count, fail_count + 1, errors ++ [error_info]}

        _ ->
          # Unexpected format, treat as failure
          {success_count, fail_count + 1,
           errors ++ [%{error: "Unexpected result format", result: result}]}
      end
    end)
  end

  defp parse_import_results(_), do: {0, 0, ["Non-list result from import"]}

  defp format_for_typesense(contact) do
    # Based on the existing format from reindex_contacts.ex
    inserted_at = format_timestamp(contact.inserted_at)
    updated_at = format_timestamp(contact.updated_at)

    # Get tag names as a list of strings
    tags = ContactTags.contact_tags_for_contact_id(contact.id)

    contact
    |> Map.from_struct()
    |> Map.drop([:__meta__, :inserted_at, :updated_at, :unified_contact, :notes, :events, :tags])
    |> Map.merge(%{
      inserted_at: inserted_at,
      updated_at: updated_at,
      # Ensure ptt is never nil for TypeSense
      ptt: contact.ptt || 0,
      tags: tags
    })
    |> add_location_if_present()
    |> ensure_required_fields()
  end

  defp add_location_if_present(contact_data) do
    case {contact_data[:latitude], contact_data[:longitude]} do
      {%Decimal{} = lat, %Decimal{} = lng} ->
        lat_float = Decimal.to_float(lat)
        lng_float = Decimal.to_float(lng)
        Map.put(contact_data, :location, [lat_float, lng_float])

      {nil, _} ->
        contact_data

      {_, nil} ->
        contact_data

      _ ->
        contact_data
    end
  end

  defp ensure_required_fields(contact_data) do
    # Ensure all required TypeSense fields are present
    contact_data
    |> Map.put_new(:first_name, nil)
    |> Map.put_new(:last_name, nil)
    |> Map.put_new(:email, nil)
    |> Map.put_new(:city, nil)
    |> Map.put_new(:state, nil)
    |> Map.put_new(:zip, nil)
    # Tags are already set in format_for_typesense, don't override with empty list
    |> Map.put_new(:tags, Map.get(contact_data, :tags, []))
  end

  defp format_timestamp(nil), do: DateTime.to_unix(DateTime.utc_now())

  defp format_timestamp(%NaiveDateTime{} = timestamp) do
    timestamp
    |> DateTime.from_naive!("Etc/UTC")
    |> DateTime.to_unix()
  end

  defp format_timestamp(timestamp) when is_binary(timestamp) do
    case NaiveDateTime.from_iso8601(timestamp) do
      {:ok, naive_datetime} -> format_timestamp(naive_datetime)
      _ -> DateTime.to_unix(DateTime.utc_now())
    end
  end

  defp default_progress_callback(processed, total) do
    percentage = Float.round(processed / total * 100, 1)
    Logger.info("Progress: #{processed}/#{total} (#{percentage}%)")
  end
end
