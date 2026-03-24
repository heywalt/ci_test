defmodule WaltUi.ProcessManagers.EnrichmentOrchestrationManager do
  @moduledoc false

  use Commanded.ProcessManagers.ProcessManager,
    application: CQRS,
    name: __MODULE__,
    start_from: :current,
    event_timeout: :timer.seconds(10)

  use TypedStruct

  require Logger

  alias CQRS.Enrichments.Commands.RequestEnrichmentComposition
  alias CQRS.Enrichments.Commands.RequestProviderEnrichment
  alias CQRS.Enrichments.Events.EnrichmentRequested
  alias CQRS.Enrichments.Events.ProviderEnrichmentCompleted
  alias WaltUi.Projections.Endato
  alias WaltUi.Projections.Trestle

  @derive Jason.Encoder
  typedstruct do
    field :id, Ecto.UUID.t()
    field :contact_data, map(), default: %{}
    field :provider_data, map(), default: %{}
    field :provider_config, map(), default: %{}
  end

  def interested?(%{id: nil} = event) do
    Logger.error("EnrichmentOrchestrationManager: Event without ID",
      module: __MODULE__,
      details: inspect(event)
    )

    false
  end

  def interested?(%EnrichmentRequested{id: id}), do: {:continue, id}

  def interested?(%ProviderEnrichmentCompleted{
        id: id,
        provider_type: "trestle",
        status: "success"
      }) do
    {:continue, id}
  end

  def interested?(%ProviderEnrichmentCompleted{
        id: id,
        provider_type: "faraday",
        status: "success"
      }) do
    {:continue, id}
  end

  # Stop process for failed provider enrichments
  def interested?(%ProviderEnrichmentCompleted{id: id, provider_type: "trestle", status: "error"}) do
    {:stop, id}
  end

  def interested?(%ProviderEnrichmentCompleted{id: id, provider_type: "faraday", status: "error"}) do
    {:continue, id}
  end

  def interested?(_event), do: false

  def after_command(_state, %RequestEnrichmentComposition{provider_data: provider_data} = cmd) do
    decision =
      case provider_data |> Enum.map(& &1.provider_type) |> Enum.sort() do
        [:trestle] -> :continue
        ["trestle"] -> :continue
        _else -> :stop
      end

    Logger.info("EnrichmentOrchestrationManager: #{decision}",
      event_id: cmd.id,
      module: __MODULE__
    )

    decision
  end

  def after_command(_state, _command), do: :continue

  # Handle EnrichmentRequested by dispatching Trestle request
  def handle(_state, %EnrichmentRequested{} = event) do
    contact_data = %{
      email: event.email,
      first_name: event.first_name,
      last_name: event.last_name,
      phone: event.phone,
      user_id: event.user_id
    }

    [
      RequestProviderEnrichment.new(%{
        id: event.id,
        provider_type: "trestle",
        contact_data: contact_data
      })
    ]
  end

  def handle(nil, event) do
    Logger.error("EnrichmentOrchestrationManager: Handling event without state",
      event_id: event.id,
      event_type: event.__struct__,
      module: __MODULE__
    )

    []
  end

  # Handle successful Trestle completion by requesting Faraday only (no composition yet)
  def handle(
        state,
        %ProviderEnrichmentCompleted{provider_type: "trestle", status: "success"} = event
      ) do
    Logger.info("EnrichmentOrchestrationManager: Handling trestle success",
      event_id: event.id,
      module: __MODULE__
    )

    # Update contact_data with Trestle enrichment data for Faraday
    updated_contact_data = extract_contact_data(state.contact_data, event.enrichment_data)
    addresses = Map.get(updated_contact_data, :addresses, [])

    if Enum.empty?(addresses) do
      # No addresses available (e.g., all were PO Boxes) - skip Faraday and go to composition
      Logger.info("EnrichmentOrchestrationManager: No addresses available, skipping Faraday",
        event_id: event.id,
        module: __MODULE__
      )

      provider_data_map = %{
        "trestle" => %{
          enrichment_data: event.enrichment_data,
          quality_metadata: event.quality_metadata
        }
      }

      [
        RequestEnrichmentComposition.new(%{
          id: event.id,
          provider_data: format_provider_data_for_composition(provider_data_map),
          composition_rules: :default
        })
      ]
    else
      [
        RequestProviderEnrichment.new(%{
          id: event.id,
          provider_type: "faraday",
          contact_data: updated_contact_data
        })
      ]
    end
  end

  # Handle Faraday completion (success or failure) by requesting composition if Trestle data exists
  def handle(
        state,
        %ProviderEnrichmentCompleted{provider_type: "faraday"} = event
      ) do
    Logger.info("EnrichmentOrchestrationManager: Handling faraday completion",
      event_id: event.id,
      status: event.status,
      module: __MODULE__
    )

    # Try to get provider data from state or recover from projections
    case get_or_recover_provider_data(state, event.id) do
      {:ok, provider_data} ->
        # Include current Faraday event data with existing/recovered state data for final composition
        current_provider_data = format_provider_data_with_current_event(provider_data, event)

        [
          RequestEnrichmentComposition.new(%{
            id: event.id,
            provider_data: current_provider_data,
            composition_rules: :default
          })
        ]

      {:error, :no_trestle_data} ->
        Logger.warning(
          "EnrichmentOrchestrationManager: No Trestle data available, skipping composition",
          event_id: event.id,
          module: __MODULE__
        )

        []
    end
  end

  # Initialize state from EnrichmentRequested
  def apply(nil, %EnrichmentRequested{} = event) do
    %__MODULE__{
      id: event.id,
      contact_data: %{
        email: event.email,
        first_name: event.first_name,
        last_name: event.last_name,
        phone: event.phone,
        user_id: event.user_id
      }
    }
  end

  # Update state with provider completion data (success or failure)
  def apply(state, %ProviderEnrichmentCompleted{} = event) do
    Logger.info("EnrichmentOrchestrationManager: Applying #{event.provider_type} #{event.status}",
      details: inspect(event.provider_type),
      event_id: event.id,
      module: __MODULE__
    )

    # Only store data for successful completions
    updated_provider_data =
      if event.status == "success" do
        Map.put(state.provider_data, to_string(event.provider_type), %{
          enrichment_data: event.enrichment_data,
          quality_metadata: event.quality_metadata
        })
      else
        state.provider_data
      end

    # For Trestle success, also update contact data
    state = state || %__MODULE__{}
    updated_state = %{state | id: event.id, provider_data: updated_provider_data}

    if event.provider_type == "trestle" && event.status == "success" do
      %{
        updated_state
        | contact_data: extract_contact_data(state.contact_data, event.enrichment_data)
      }
    else
      updated_state
    end
  end

  def error(error, event, ctx) do
    Logger.error("EnrichmentOrchestrationManager: Error dispatching command",
      details: inspect(ctx.last_event),
      event_id: event.id,
      event_type: event.__struct__,
      module: __MODULE__,
      reason: inspect(error)
    )

    :skip
  end

  # Extract and merge contact data from enrichment results
  defp extract_contact_data(existing_contact_data, enrichment_data) do
    phone =
      CQRS.Utils.get(enrichment_data, :phone) ||
        CQRS.Utils.get(existing_contact_data, :phone)

    existing_contact_data
    |> maybe_update(:first_name, CQRS.Utils.get(enrichment_data, :first_name))
    |> maybe_update(:last_name, CQRS.Utils.get(enrichment_data, :last_name))
    |> maybe_update(:addresses, CQRS.Utils.get(enrichment_data, :addresses))
    |> maybe_update(:phone, phone)
    |> maybe_update_email(CQRS.Utils.get(enrichment_data, :emails))
  end

  defp maybe_update(contact_data, _key, nil), do: contact_data
  defp maybe_update(contact_data, key, value), do: Map.put(contact_data, key, value)

  # Only update email if we don't already have one
  defp maybe_update_email(%{email: nil} = contact_data, [email | _]) when is_binary(email) do
    Map.put(contact_data, :email, email)
  end

  defp maybe_update_email(contact_data, _), do: contact_data

  # Convert the provider_data map to a list of maps for composition
  defp format_provider_data_for_composition(provider_data_map) do
    Enum.map(provider_data_map, fn {provider_type, data} ->
      %{
        provider_type: to_string(provider_type),
        status: "success",
        enrichment_data: data.enrichment_data,
        quality_metadata: data.quality_metadata,
        received_at: NaiveDateTime.truncate(NaiveDateTime.utc_now(), :second)
      }
    end)
  end

  # Include current event data with existing state data for immediate composition
  defp format_provider_data_with_current_event(existing_provider_data, event) do
    # Only add current event data if it was successful
    updated_provider_data =
      if event.status == "success" do
        Map.put(existing_provider_data, to_string(event.provider_type), %{
          enrichment_data: event.enrichment_data,
          quality_metadata: event.quality_metadata
        })
      else
        existing_provider_data
      end

    # Convert to composition format
    format_provider_data_for_composition(updated_provider_data)
  end

  # Get provider data from state or recover from projections if Trestle data is missing
  defp get_or_recover_provider_data(state, enrichment_id) do
    if Map.has_key?(state.provider_data, "trestle") do
      {:ok, state.provider_data}
    else
      # Try to recover Trestle data from projection
      case Repo.get(Trestle, enrichment_id) do
        %Trestle{} = trestle_projection ->
          # Recover provider data map from projections
          recovered_data = %{
            "trestle" => %{
              enrichment_data: projection_to_enrichment_data(trestle_projection),
              quality_metadata: trestle_projection.quality_metadata
            }
          }

          # Also recover other provider data if available
          recovered_data = maybe_add_endato_data(recovered_data, enrichment_id)

          {:ok, recovered_data}

        nil ->
          {:error, :no_trestle_data}
      end
    end
  end

  # Convert Trestle projection back to enrichment_data format
  defp projection_to_enrichment_data(trestle_projection) do
    addresses =
      case trestle_projection.addresses do
        addresses when is_nil(addresses) or addresses == [] -> []
        addresses -> convert_addresses_to_maps(addresses)
      end

    %{
      first_name: trestle_projection.first_name,
      last_name: trestle_projection.last_name,
      emails: trestle_projection.emails,
      alternate_names: trestle_projection.alternate_names || [],
      age_range: trestle_projection.age_range,
      addresses: addresses
    }
    |> Enum.reject(fn {_k, v} -> is_nil(v) end)
    |> Map.new()
  end

  # Convert embedded address structs to atom-key maps
  defp convert_addresses_to_maps(addresses) do
    Enum.map(addresses, fn address ->
      %{
        street_1: get_address_field(address, :street_1),
        street_2: get_address_field(address, :street_2),
        city: get_address_field(address, :city),
        state: get_address_field(address, :state),
        zip: get_address_field(address, :zip)
      }
      |> Enum.reject(fn {_k, v} -> is_nil(v) end)
      |> Map.new()
    end)
  end

  # Safely get address field from struct or map (with atom or string keys)
  defp get_address_field(address, field) when is_map(address) do
    Map.get(address, field) || Map.get(address, to_string(field))
  end

  defp get_address_field(_address, _field), do: nil

  # Optionally recover Endato data if available
  defp maybe_add_endato_data(provider_data, enrichment_id) do
    case Repo.get(Endato, enrichment_id) do
      %Endato{} = endato_projection ->
        endato_data = %{
          enrichment_data: endato_projection_to_enrichment_data(endato_projection),
          quality_metadata: endato_projection.quality_metadata
        }

        Map.put(provider_data, "endato", endato_data)

      nil ->
        provider_data
    end
  end

  # Convert Endato projection back to enrichment_data format
  defp endato_projection_to_enrichment_data(endato_projection) do
    %{
      first_name: endato_projection.first_name,
      last_name: endato_projection.last_name,
      emails: endato_projection.emails,
      addresses: endato_projection.addresses || []
    }
    |> Enum.reject(fn {_k, v} -> is_nil(v) or v == [] end)
    |> Map.new()
  end
end
