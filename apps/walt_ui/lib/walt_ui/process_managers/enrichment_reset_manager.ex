defmodule WaltUi.ProcessManagers.EnrichmentResetManager do
  @moduledoc false

  use Commanded.ProcessManagers.ProcessManager,
    application: CQRS,
    start_from: :current,
    name: __MODULE__

  use TypedStruct

  import Ecto.Query

  require Logger

  alias CQRS.Enrichments.Events.EnrichmentReset
  alias CQRS.Leads.Commands.Update
  alias WaltUi.Projections.Contact

  @derive Jason.Encoder
  typedstruct do
    # Process managers need an id field
    field :id, String.t()
  end

  @impl true
  def interested?(%EnrichmentReset{} = event) do
    {:start, event.id}
  end

  def interested?(_event), do: false

  @impl true
  def handle(%{id: _id}, %EnrichmentReset{} = event) do
    Logger.info("Processing EnrichmentReset for enrichment_id: #{event.id}")

    # Find all contacts with this enrichment_id
    contacts =
      from(c in Contact,
        where: c.enrichment_id == ^event.id,
        select: %{id: c.id, user_id: c.user_id}
      )
      |> Repo.all()

    # Generate Update commands for each contact to reset enrichment data
    commands =
      Enum.map(contacts, fn contact ->
        %Update{
          id: contact.id,
          user_id: contact.user_id,
          timestamp: event.timestamp,
          attrs: %{
            enrichment_id: nil,
            ptt: nil,
            city: nil,
            state: nil,
            street_1: nil,
            street_2: nil,
            zip: nil
          }
        }
      end)

    Logger.info("Dispatching #{length(commands)} Update commands for EnrichmentReset")

    commands
  end

  @impl true
  def apply(state, %EnrichmentReset{} = event) do
    %__MODULE__{state | id: event.id}
  end

  @impl true
  def error(error, _event, _failure_context) do
    Logger.error("EnrichmentResetManager error: #{inspect(error)}")
    :skip
  end
end
