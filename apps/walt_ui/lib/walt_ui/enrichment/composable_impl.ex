defimpl WaltUi.Enrichment.Composable, for: CQRS.Enrichments.Data.ProviderData do
  @moduledoc """
  Implementation of Composable protocol for ProviderData structs.

  Dispatches based on provider_type to handle provider-specific logic.
  """

  alias CQRS.Enrichments.Data.ProviderData

  def normalize_data(%ProviderData{provider_type: "trestle"} = provider_data) do
    enrichment_data = provider_data.enrichment_data

    # Start with base fields (excluding addresses and emails lists)
    base_fields = Map.drop(enrichment_data, [:addresses, :emails, :age_range])

    # Add first address fields if available
    address_fields = extract_trestle_address_fields(enrichment_data)

    # Add first email if available
    email_field = extract_trestle_email(enrichment_data)

    # Map age_range to age field
    age_field = extract_trestle_age(enrichment_data)

    base_fields
    |> Map.merge(address_fields)
    |> Map.merge(email_field)
    |> Map.merge(age_field)
  end

  def normalize_data(%ProviderData{provider_type: "faraday"} = provider_data) do
    provider_data.enrichment_data
    |> normalize_faraday_ptt()
    |> normalize_faraday_address_fields()
  end

  def normalize_data(%ProviderData{provider_type: "endato"} = provider_data) do
    # Endato data normalization
    enrichment_data = provider_data.enrichment_data || %{}

    # Start with base fields (excluding addresses and emails lists)
    base_fields = Map.drop(enrichment_data, [:addresses, :emails])

    # Add first address fields if available
    address_fields = extract_endato_address_fields(enrichment_data)

    # Add first email if available
    email_field = extract_endato_email(enrichment_data)

    base_fields
    |> Map.merge(address_fields)
    |> Map.merge(email_field)
  end

  # Catch-all for unknown provider types
  def normalize_data(%ProviderData{} = provider_data) do
    # Return enrichment_data as-is for unknown provider types
    provider_data.enrichment_data || %{}
  end

  # Private helpers for Faraday normalization

  defp normalize_faraday_ptt(enrichment_data) do
    case CQRS.Utils.get(enrichment_data, :propensity_to_transact) do
      ptt when is_float(ptt) ->
        enrichment_data
        |> Map.put(:ptt, trunc(ptt * 100))
        |> Map.delete(:propensity_to_transact)
        |> Map.delete("propensity_to_transact")

      ptt when is_integer(ptt) ->
        enrichment_data
        |> Map.put(:ptt, ptt)
        |> Map.delete(:propensity_to_transact)
        |> Map.delete("propensity_to_transact")

      _ ->
        enrichment_data
    end
  end

  # Transform Faraday address fields to match standard format
  # :address -> :street_1, :postcode -> :zip
  defp normalize_faraday_address_fields(enrichment_data) do
    enrichment_data
    |> maybe_rename_field(:address, :street_1)
    |> maybe_rename_field(:postcode, :zip)
  end

  defp maybe_rename_field(map, old_key, new_key) do
    case CQRS.Utils.get(map, old_key) do
      nil ->
        map

      value ->
        map
        |> Map.delete(old_key)
        |> Map.put(new_key, value)
    end
  end

  def calculate_quality_score(%ProviderData{provider_type: "trestle"} = provider_data) do
    quality_metadata = provider_data.quality_metadata
    match_count = quality_metadata[:match_count]
    name_hint = quality_metadata[:name_hint]

    cond do
      is_nil(match_count) -> 50
      match_count == 0 -> 10
      match_count == 1 -> trestle_single_match_score(provider_data, name_hint)
      match_count > 1 -> trestle_multi_match_score(provider_data, name_hint)
      true -> 50
    end
  end

  def calculate_quality_score(%ProviderData{provider_type: "faraday"} = provider_data) do
    quality_metadata = provider_data.quality_metadata
    match_type = quality_metadata[:match_type]

    faraday_match_type_score(match_type)
  end

  def calculate_quality_score(%ProviderData{provider_type: "endato"} = provider_data) do
    quality_metadata = provider_data.quality_metadata
    match_score = quality_metadata[:match_score]

    case match_score do
      score when is_integer(score) and score >= 0 and score <= 100 -> score
      _ -> 50
    end
  end

  # Catch-all for unknown provider types
  def calculate_quality_score(%ProviderData{} = _provider_data) do
    50
  end

  def extract_field(%ProviderData{} = provider_data, field) do
    normalized_data = normalize_data(provider_data)
    Map.get(normalized_data, field)
  end

  def get_field_capabilities(%ProviderData{provider_type: "trestle"}) do
    [
      :first_name,
      :last_name,
      :age,
      :email,
      :city,
      :state,
      :street_1,
      :street_2,
      :zip
    ]
  end

  def get_field_capabilities(%ProviderData{provider_type: "faraday"}) do
    [
      :age,
      :first_name,
      :last_name,
      :city,
      :state,
      :street_1,
      :zip,
      :household_income,
      :education,
      :occupation,
      :marital_status,
      :has_pet,
      :likes_travel,
      :has_children_in_household,
      :is_active_on_social_media,
      :property_type,
      :number_of_bedrooms,
      :number_of_bathrooms,
      :garage_spaces,
      :ptt
    ]
  end

  def get_field_capabilities(%ProviderData{provider_type: "endato"}) do
    [
      :first_name,
      :last_name,
      :email,
      :city,
      :state,
      :street_1,
      :street_2,
      :zip
    ]
  end

  # Catch-all for unknown provider types
  def get_field_capabilities(%ProviderData{}) do
    []
  end

  # Private helper functions for Trestle data extraction

  defp extract_trestle_address_fields(enrichment_data) do
    case CQRS.Utils.get(enrichment_data, :addresses, []) do
      [first_address | _] ->
        first_address
        |> Map.take([:city, :state, :street_1, :street_2, :zip])
        |> Enum.reject(fn {_k, v} -> is_nil(v) end)
        |> Map.new()

      _ ->
        %{}
    end
  end

  defp extract_trestle_email(enrichment_data) do
    case CQRS.Utils.get(enrichment_data, :emails, []) do
      [first_email | _] -> %{email: first_email}
      _ -> %{}
    end
  end

  defp extract_trestle_age(enrichment_data) do
    case CQRS.Utils.get(enrichment_data, :age_range) do
      nil -> %{}
      age_range -> %{age: age_range}
    end
  end

  # Private helper functions for Endato data extraction

  defp extract_endato_address_fields(enrichment_data) do
    case CQRS.Utils.get(enrichment_data, :addresses, []) do
      [first_address | _] ->
        first_address
        |> Map.take([:city, :state, :street_1, :street_2, :zip])
        |> Enum.reject(fn {_k, v} -> is_nil(v) end)
        |> Map.new()

      _ ->
        %{}
    end
  end

  defp extract_endato_email(enrichment_data) do
    case CQRS.Utils.get(enrichment_data, :emails, []) do
      [first_email | _] -> %{email: first_email}
      _ -> %{}
    end
  end

  # Name matching helpers for Trestle quality scoring

  defp exact_name_match?(provider_data, name_hint) when is_binary(name_hint) do
    enrichment_data = provider_data.enrichment_data
    first_name = CQRS.Utils.get(enrichment_data, :first_name)
    last_name = CQRS.Utils.get(enrichment_data, :last_name)

    expected_full_name = String.trim("#{first_name || ""} #{last_name || ""}")
    normalize_name(expected_full_name) == normalize_name(name_hint)
  end

  defp exact_name_match?(_provider_data, _name_hint), do: false

  defp partial_name_match?(provider_data, name_hint) when is_binary(name_hint) do
    enrichment_data = provider_data.enrichment_data
    first_name = CQRS.Utils.get(enrichment_data, :first_name)
    last_name = CQRS.Utils.get(enrichment_data, :last_name)

    normalized_hint = normalize_name(name_hint)

    (first_name && String.contains?(normalized_hint, normalize_name(first_name))) ||
      (last_name && String.contains?(normalized_hint, normalize_name(last_name)))
  end

  defp partial_name_match?(_provider_data, _name_hint), do: false

  defp name_mismatch?(provider_data, name_hint) when is_binary(name_hint) do
    # If we have a name hint but neither exact nor partial match, it's a mismatch
    !exact_name_match?(provider_data, name_hint) && !partial_name_match?(provider_data, name_hint)
  end

  defp name_mismatch?(_provider_data, _name_hint), do: false

  defp faraday_match_type_score("address_full_name"), do: 90
  defp faraday_match_type_score("phone_full_name"), do: 80
  defp faraday_match_type_score("email_full_name"), do: 70
  defp faraday_match_type_score("address_last_name"), do: 50
  defp faraday_match_type_score("phone_last_name"), do: 45
  defp faraday_match_type_score("email_last_name"), do: 35
  defp faraday_match_type_score("address_only"), do: 20
  defp faraday_match_type_score("email_only"), do: 10
  defp faraday_match_type_score(nil), do: 0
  defp faraday_match_type_score(_), do: 20

  defp trestle_single_match_score(provider_data, name_hint) do
    cond do
      exact_name_match?(provider_data, name_hint) -> 95
      partial_name_match?(provider_data, name_hint) -> 85
      name_mismatch?(provider_data, name_hint) -> 20
      true -> 75
    end
  end

  defp trestle_multi_match_score(provider_data, name_hint) do
    cond do
      exact_name_match?(provider_data, name_hint) -> 90
      partial_name_match?(provider_data, name_hint) -> 65
      true -> 45
    end
  end

  defp normalize_name(name) when is_binary(name) do
    name |> String.downcase() |> String.trim()
  end

  defp normalize_name(_), do: ""
end

defimpl WaltUi.Enrichment.Composable, for: Map do
  alias CQRS.Enrichments.Data.ProviderData
  alias WaltUi.Enrichment.Composable

  def normalize_data(map_data) do
    case convert_map_to_provider_data(map_data) do
      {:ok, provider_data} -> Composable.normalize_data(provider_data)
      :error -> %{}
    end
  end

  def calculate_quality_score(map_data) do
    case convert_map_to_provider_data(map_data) do
      {:ok, provider_data} -> Composable.calculate_quality_score(provider_data)
      :error -> 0
    end
  end

  def extract_field(map_data, field) do
    case convert_map_to_provider_data(map_data) do
      {:ok, provider_data} -> Composable.extract_field(provider_data, field)
      :error -> nil
    end
  end

  def get_field_capabilities(map_data) do
    case convert_map_to_provider_data(map_data) do
      {:ok, provider_data} -> Composable.get_field_capabilities(provider_data)
      :error -> []
    end
  end

  defp convert_map_to_provider_data(map_data) when is_map(map_data) do
    provider_data = %ProviderData{
      provider_type: CQRS.Utils.get(map_data, :provider_type),
      status: CQRS.Utils.get(map_data, :status),
      enrichment_data: convert_keys_to_atoms(CQRS.Utils.get(map_data, :enrichment_data, %{})),
      error_data: convert_keys_to_atoms(CQRS.Utils.get(map_data, :error_data, %{})),
      quality_metadata: convert_keys_to_atoms(CQRS.Utils.get(map_data, :quality_metadata, %{})),
      received_at: parse_received_at(CQRS.Utils.get(map_data, :received_at))
    }

    case ProviderData.validate(provider_data) do
      :ok -> {:ok, provider_data}
      {:error, _} -> :error
    end
  rescue
    _ -> :error
  end

  defp convert_map_to_provider_data(_), do: :error

  defp parse_received_at(datetime_string) when is_binary(datetime_string) do
    case NaiveDateTime.from_iso8601(datetime_string) do
      {:ok, naive_datetime} -> naive_datetime
      {:error, _} -> nil
    end
  end

  defp parse_received_at(%NaiveDateTime{} = datetime), do: datetime

  defp parse_received_at(_), do: nil

  defp convert_keys_to_atoms(map) when is_map(map) do
    map
    |> Enum.reduce(%{}, fn
      {key, value}, acc when is_binary(key) ->
        atom_key = String.to_atom(key)
        Map.put(acc, atom_key, deep_convert_keys_to_atoms(value))

      {key, value}, acc ->
        Map.put(acc, key, deep_convert_keys_to_atoms(value))
    end)
  rescue
    ArgumentError -> map
  end

  defp convert_keys_to_atoms(value), do: value

  defp deep_convert_keys_to_atoms(map) when is_map(map) do
    convert_keys_to_atoms(map)
  end

  defp deep_convert_keys_to_atoms(list) when is_list(list) do
    Enum.map(list, &deep_convert_keys_to_atoms/1)
  end

  defp deep_convert_keys_to_atoms(value), do: value
end
