defmodule WaltUi.Enrichment.Composer do
  @moduledoc """
  Intelligently composes enrichment data from multiple providers based on quality indicators
  and configurable business rules.

  Uses the Composable protocol to normalize provider data and assess quality scores.
  """

  require Logger
  alias WaltUi.Enrichment.Composable
  alias WaltUi.Enrichment.PttWrapper

  @doc """
  Composes enrichment data from multiple providers into a single result.

  Returns a map with:
  - composed_data: The final enriched contact data
  - data_sources: Map showing which provider was selected for each field
  - provider_scores: Map showing quality score for each successful provider
  """
  def compose(provider_data, _composition_rules, enrichment_id) do
    # Filter out providers with errors
    successful_providers = Enum.filter(provider_data, &(&1.status == "success"))

    # Compose the data using all successful providers
    {composed_data, data_sources} = compose_fields(successful_providers)

    # Apply Move Score adjustments based on business rules
    adjusted_composed_data = apply_ptt_adjustments(composed_data, provider_data)

    # Calculate provider scores for successful providers
    provider_scores = calculate_provider_scores(successful_providers)

    # Log composition completion
    Logger.info("Data composition completed",
      event_id: enrichment_id,
      provider_scores: provider_scores,
      module: __MODULE__
    )

    %{
      composed_data: adjusted_composed_data,
      data_sources: data_sources,
      provider_scores: provider_scores
    }
  end

  defp compose_fields(provider_data_list) do
    # Normalize data for all providers using protocol
    normalized_providers =
      Enum.map(provider_data_list, fn provider ->
        {provider, Composable.normalize_data(provider)}
      end)

    # Get all fields from all normalized providers
    all_fields =
      normalized_providers
      |> Enum.flat_map(fn {_provider, normalized} -> Map.keys(normalized) end)
      |> Enum.uniq()

    all_fields
    |> Enum.reduce({%{}, %{}}, fn field, {data, sources} ->
      case select_best_provider_for_field(field, normalized_providers) do
        {provider_type, value} ->
          {Map.put(data, field, value), Map.put(sources, field, provider_type)}

        :none ->
          {data, sources}
      end
    end)
  end

  defp select_best_provider_for_field(field, normalized_providers) do
    # Get providers that have this field
    providers_with_field =
      normalized_providers
      |> Enum.filter(fn {_provider, normalized} -> Map.has_key?(normalized, field) end)
      |> Enum.map(fn {provider, normalized} ->
        {provider, Map.get(normalized, field)}
      end)

    case providers_with_field do
      [] ->
        :none

      [{provider, value}] ->
        # Only one provider has this field
        {provider.provider_type, value}

      multiple_providers ->
        # Multiple providers have this field - use selection strategy
        cond do
          field == :age ->
            select_by_quality_score(field, multiple_providers)

          field in [:city, :state, :street_1, :street_2, :zip] ->
            select_address_field(field, multiple_providers)

          true ->
            select_by_field_capabilities(field, multiple_providers)
        end
    end
  end

  defp select_by_quality_score(_field, providers_with_field) do
    # Select provider with highest quality score
    {best_provider, best_value} =
      providers_with_field
      |> Enum.max_by(fn {provider, _value} ->
        Composable.calculate_quality_score(provider)
      end)

    {best_provider.provider_type, best_value}
  end

  defp select_address_field(_field, providers_with_field) do
    # Prefer Faraday for address fields since demographic data (Move Score, etc.)
    # is calculated based on the address Faraday matched on
    {provider, value} = select_preferred_address_provider(providers_with_field)
    {provider.provider_type, value}
  end

  defp select_preferred_address_provider(providers) do
    select_preferred_address_provider(providers, :faraday)
  end

  defp select_preferred_address_provider(providers, :faraday) do
    case Enum.find(providers, fn {p, _} -> p.provider_type == "faraday" end) do
      nil -> select_preferred_address_provider(providers, :trestle)
      result -> result
    end
  end

  defp select_preferred_address_provider(providers, :trestle) do
    case Enum.find(providers, fn {p, _} -> p.provider_type == "trestle" end) do
      nil -> List.first(providers)
      result -> result
    end
  end

  defp select_by_field_capabilities(field, providers_with_field) do
    # Find provider that excels at this field type
    provider_with_capability =
      Enum.find(providers_with_field, fn {provider, _value} ->
        capabilities = Composable.get_field_capabilities(provider)
        field in capabilities
      end)

    case provider_with_capability do
      {provider, value} ->
        {provider.provider_type, value}

      nil ->
        # No provider excels at this field, use highest quality score
        select_by_quality_score(field, providers_with_field)
    end
  end

  defp calculate_provider_scores(successful_providers) do
    Enum.reduce(successful_providers, %{}, fn provider, acc ->
      score = Composable.calculate_quality_score(provider)
      Map.put(acc, provider.provider_type, score)
    end)
  end

  defp apply_ptt_adjustments(composed_data, provider_data) do
    case Map.get(composed_data, :ptt) do
      nil ->
        composed_data

      ptt ->
        adjusted_ptt = PttWrapper.adjust(ptt, provider_data)
        Map.put(composed_data, :ptt, adjusted_ptt)
    end
  end
end
