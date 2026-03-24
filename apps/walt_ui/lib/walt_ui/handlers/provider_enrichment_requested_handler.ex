defmodule WaltUi.Handlers.ProviderEnrichmentRequestedHandler do
  @moduledoc """
  Event handler that bridges CQRS events to Oban background jobs.

  Listens for ProviderEnrichmentRequested events and enqueues the appropriate
  Oban job based on the provider_type to make external API calls.
  """

  use Commanded.Event.Handler,
    application: CQRS,
    name: __MODULE__,
    start_from: :current

  require Logger

  alias CQRS.Enrichments.Events.ProviderEnrichmentRequested
  alias WaltUi.Enrichment.FaradayJob
  alias WaltUi.Enrichment.TrestleJob

  @impl Commanded.Event.Handler
  def handle(%ProviderEnrichmentRequested{} = event, _metadata) do
    Logger.metadata(event_id: event.id, provider_type: event.provider_type)

    Logger.info("Enqueuing job for enrichment")

    case enqueue_provider_job(event) do
      {:ok, job} ->
        Logger.debug("Successfully enqueued job", job_id: job.id)
        :ok

      {:error, reason} ->
        Logger.error("Failed to enqueue job", reason: inspect(reason))
        {:error, reason}
    end
  end

  # Route to appropriate Oban job based on provider type
  defp enqueue_provider_job(%ProviderEnrichmentRequested{provider_type: "trestle"} = event) do
    insert_new_job(event, &TrestleJob.new/1)
  end

  defp enqueue_provider_job(%ProviderEnrichmentRequested{provider_type: "faraday"} = event) do
    insert_new_job(event, &FaradayJob.new/1)
  end

  defp enqueue_provider_job(%ProviderEnrichmentRequested{provider_type: unknown_provider}) do
    Logger.error("Unknown provider type")
    {:error, {:unknown_provider, unknown_provider}}
  end

  defp insert_new_job(event, job_new_fn) do
    user_id = event.contact_data["user_id"] || event.contact_data[:user_id]

    event
    |> Map.from_struct()
    |> then(&%{"event" => &1, "user_id" => user_id})
    |> job_new_fn.()
    |> Oban.insert()
  end
end
