defmodule WaltUi.Search.JitterSearchJob do
  @moduledoc """
  Job that runs weekly to take all jittered contacts and update their documents in Typesense.

  This is done so that when filtering records, or when the AI is searching for records,
  their Move Scores are the same. Without this, we render the Jittered scores as the
  Move Score for contacts, but the index/filtered results would show their actual Move Score.
  """
  use Oban.Worker, queue: :jitter_search, max_attempts: 1

  alias WaltUi.Scripts.BulkUpdateUserContacts

  require Logger

  def perform(_job) do
    Logger.info("Running JitterSearchJob")

    BulkUpdateUserContacts.bulk_update_jittered_contacts()

    :ok
  end
end
