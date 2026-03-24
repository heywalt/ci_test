defmodule WaltUi.Enrichment.TrestleJob do
  @moduledoc false

  use Oban.Pro.Worker, queue: :trestle, max_attempts: 10

  require Logger

  alias CQRS.Enrichments.Commands.CompleteProviderEnrichment
  alias WaltUi.Enrichment.Trestle
  alias WaltUi.Enrichment.TrestleOwnerSelector

  # Define structured arguments schema
  args_schema do
    field :user_id, :string
    field :event, :map, required: true
  end

  @impl Oban.Pro.Worker
  def process(%{args: %{event: event, user_id: user_id}}) do
    event = normalize_event(event)
    Logger.metadata(event_id: event.id, user_id: user_id, module: __MODULE__)

    phone = event.contact_data.phone
    name_hint = build_name_hint(event.contact_data)
    opts = if name_hint, do: [name_hint: name_hint], else: []

    case Trestle.search_by_phone(phone, opts) do
      {:ok, %{"owners" => [_ | _] = owners}} ->
        Logger.info("Found Trestle enrichment data")
        dispatch_completion(owners, name_hint, event)

      {:ok, _empty_or_no_owners} ->
        Logger.info("No Trestle data found")
        dispatch_error_completion(event, %{reason: :no_owners_found})

      {:error, error} ->
        Logger.warning("Failed to get Trestle data", details: inspect(error))
        dispatch_error_completion(event, %{reason: error})
    end
  end

  defp normalize_addresses(addresses) when is_list(addresses) do
    addresses
    |> Enum.map(&normalize_address/1)
    |> Enum.filter(&valid_address?/1)
    |> Enum.reject(&po_box?/1)
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

  defp po_box?(%{street_1: street_1}) when is_binary(street_1) do
    street_1
    |> String.downcase()
    |> String.replace(".", "")
    |> String.starts_with?("po box")
  end

  defp po_box?(_address), do: false

  defp normalize_address(addr) do
    %{
      city: normalize_string(addr["city"]),
      state: normalize_string(addr["state_code"]),
      street_1: normalize_string(addr["street_line_1"]),
      street_2: addr["street_line_2"],
      zip: normalize_string(addr["postal_code"])
    }
  end

  defp normalize_string(nil), do: nil

  defp normalize_string(str) when is_binary(str) do
    trimmed = String.trim(str)
    if trimmed == "", do: nil, else: trimmed
  end

  defp normalize_event(event) when is_map(event) do
    %{
      id: Map.get(event, :id, event["id"]),
      provider_type: Map.get(event, :provider_type, event["provider_type"]),
      contact_data:
        event |> Map.get(:contact_data, event["contact_data"]) |> normalize_contact_data(),
      provider_config: Map.get(event, :provider_config, event["provider_config"]),
      timestamp: Map.get(event, :timestamp, event["timestamp"])
    }
  end

  defp normalize_contact_data(contact_data) when is_map(contact_data) do
    %{
      phone: Map.get(contact_data, :phone, contact_data["phone"]),
      first_name: Map.get(contact_data, :first_name, contact_data["first_name"]),
      last_name: Map.get(contact_data, :last_name, contact_data["last_name"]),
      email: Map.get(contact_data, :email, contact_data["email"]),
      user_id: Map.get(contact_data, :user_id, contact_data["user_id"])
    }
  end

  defp build_name_hint(%{first_name: first_name, last_name: last_name}) do
    if first_name && first_name != "" do
      String.trim("#{first_name} #{last_name}")
    end
  end

  defp dispatch_completion(owners, name_hint, event) do
    owner = TrestleOwnerSelector.select_best_owner(owners, name_hint, event.id)

    enrichment_data = %{
      age_range: owner["age_range"],
      addresses: normalize_addresses(owner["current_addresses"] || []),
      emails: owner["emails"] || [],
      first_name: owner["firstname"],
      last_name: owner["lastname"],
      phone: event.contact_data.phone,
      alternate_names: owner["alternate_names"] || []
    }

    quality_metadata = %{
      match_count: length(owners),
      name_hint: name_hint
    }

    command =
      CompleteProviderEnrichment.new(%{
        id: event.id,
        provider_type: "trestle",
        status: "success",
        enrichment_data: enrichment_data,
        quality_metadata: quality_metadata
      })

    case CQRS.dispatch(command) do
      :ok ->
        selected_owner_score = TrestleOwnerSelector.score_owner_name_match(owner, name_hint)

        Logger.info("Trestle enrichment completed",
          event_id: event.id,
          status: "success",
          owner_count: length(owners),
          selected_owner_score: selected_owner_score,
          module: __MODULE__
        )

      {:error, error} ->
        Logger.warning("Trestle enrichment failed",
          event_id: event.id,
          status: "dispatch_error",
          owner_count: length(owners),
          error: inspect(error),
          module: __MODULE__
        )

        {:error, :dispatch}
    end
  end

  defp dispatch_error_completion(event, error_data) do
    command =
      CompleteProviderEnrichment.new(%{
        id: event.id,
        provider_type: "trestle",
        status: "error",
        error_data: error_data
      })

    case CQRS.dispatch(command) do
      :ok ->
        Logger.info("Trestle enrichment completed",
          event_id: event.id,
          status: "error",
          owner_count: 0,
          selected_owner_score: 0,
          module: __MODULE__
        )

      {:error, error} ->
        Logger.warning("Trestle enrichment failed",
          event_id: event.id,
          status: "dispatch_error",
          owner_count: 0,
          error: inspect(error),
          module: __MODULE__
        )

        {:error, :dispatch}
    end
  end
end
