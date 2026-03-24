defmodule WaltUi.Handlers.EnrichmentCompositionRequestedHandler do
  @moduledoc false

  use Commanded.Event.Handler,
    application: CQRS,
    name: __MODULE__,
    start_from: :current

  require Logger

  alias CQRS.Enrichments.Commands.CompleteEnrichmentComposition
  alias CQRS.Enrichments.Events.EnrichmentCompositionRequested
  alias WaltUi.Enrichment.Composer

  def handle(%EnrichmentCompositionRequested{} = event, _metadata) do
    Logger.info("Processing composition request for enrichment #{event.id}")

    # Filter successful providers
    successful_providers = Enum.filter(event.provider_data, &(&1.status == "success"))

    case successful_providers do
      [] ->
        Logger.warning("No successful providers available for composition enrichment #{event.id}")
        :ok

      providers ->
        try do
          # Call our composition logic
          result = Composer.compose(providers, event.composition_rules, event.id)

          # Dispatch completion command
          command = %CompleteEnrichmentComposition{
            id: event.id,
            composed_data: result.composed_data,
            data_sources: result.data_sources,
            provider_scores: result.provider_scores,
            timestamp: NaiveDateTime.utc_now()
          }

          case CQRS.dispatch(command) do
            :ok ->
              Logger.info(
                "Successfully dispatched composition command for enrichment #{event.id}"
              )

              :ok

            {:error, reason} ->
              Logger.error(
                "Failed to dispatch composition command for enrichment #{event.id}: #{inspect(reason)}"
              )

              :ok
          end
        rescue
          error ->
            Logger.error("Composition failed for enrichment #{event.id}: #{inspect(error)}")
            :ok
        end
    end
  end
end
