defmodule WaltUi.Projectors.PossibleAddress do
  @moduledoc false

  use Commanded.Projections.Ecto,
    application: CQRS,
    repo: Repo,
    name: __MODULE__,
    consistency: :strong

  require Logger

  alias CQRS.Enrichments.Events.EnrichedWithEndato
  alias CQRS.Enrichments.Events.EnrichedWithTrestle
  alias CQRS.Enrichments.Events.ProviderEnrichmentCompleted
  alias WaltUi.Projections.PossibleAddress

  project %EnrichedWithEndato{} = event, _metadata, fn multi ->
    event.addresses
    |> Enum.filter(&valid_address?/1)
    |> Enum.with_index()
    |> Enum.reduce(multi, &project_address(&1, &2, event.id))
  end

  project %EnrichedWithTrestle{} = event, _metadata, fn multi ->
    event.addresses
    |> Enum.filter(&valid_address?/1)
    |> Enum.with_index()
    |> Enum.reduce(multi, &project_address(&1, &2, event.id))
  end

  project %ProviderEnrichmentCompleted{provider_type: "endato", status: "success"} = event,
          _metadata,
          fn multi ->
            case Map.get(event.enrichment_data, :addresses, []) do
              [] ->
                multi

              addresses ->
                addresses
                |> Enum.filter(&valid_address?/1)
                |> Enum.with_index()
                |> Enum.reduce(multi, &project_address(&1, &2, event.id))
            end
          end

  project %ProviderEnrichmentCompleted{provider_type: "trestle", status: "success"} = event,
          _metadata,
          fn multi ->
            case Map.get(event.enrichment_data, :addresses, []) do
              [] ->
                multi

              addresses ->
                addresses
                |> Enum.filter(&valid_address?/1)
                |> Enum.with_index()
                |> Enum.reduce(multi, &project_address(&1, &2, event.id))
            end
          end

  project %ProviderEnrichmentCompleted{}, _metadata, fn multi ->
    # Ignore non-endato/trestle providers and error status events
    multi
  end

  def to_id(enrichment_id, address) do
    addr = for {key, val} <- address, into: %{}, do: {key, downcase(val)}

    UUID.uuid5(
      :oid,
      "#{enrichment_id}:#{addr.street_1}:#{Map.get(addr, :street_2)}:#{addr.city}:#{addr.state}:#{addr.zip}"
    )
  end

  defp valid_address?(address) do
    required_fields = [:street_1, :city, :state, :zip]

    Enum.all?(required_fields, fn field ->
      case Map.get(address, field) do
        val when is_binary(val) -> String.trim(val) != ""
        _ -> false
      end
    end)
  end

  defp downcase(nil), do: ""
  defp downcase(val) when is_binary(val), do: String.downcase(val)
  defp downcase(val), do: val |> to_string() |> downcase()

  defp project_address({address, i}, multi, enrichment_id) do
    multi
    |> Ecto.Multi.put(:"id_#{i}", to_id(enrichment_id, address))
    |> Ecto.Multi.one(:"addr_#{i}", fn changes ->
      from addr in PossibleAddress, where: addr.id == ^Map.get(changes, :"id_#{i}")
    end)
    |> Ecto.Multi.run(:"insert_#{i}", fn repo, changes ->
      if Map.get(changes, :"addr_#{i}") do
        {:ok, :skipped}
      else
        address
        |> Map.merge(%{enrichment_id: enrichment_id, id: Map.get(changes, :"id_#{i}")})
        |> PossibleAddress.changeset()
        |> repo.insert()
      end
    end)
  end

  @impl Commanded.Event.Handler
  def error({:error, %Ecto.Changeset{valid?: false} = cs}, event, _ctx) do
    Logger.error("Encountered invalid changeset during address projection",
      event_id: event.id,
      event_type: event.__struct__,
      module: __MODULE__,
      reason: inspect(cs.errors)
    )

    :skip
  end

  def error(error, event, _ctx) do
    Logger.error("Error projecting possible address",
      event_id: event.id,
      event_type: event.__struct__,
      module: __MODULE__,
      reason: inspect(error)
    )

    :skip
  end
end
