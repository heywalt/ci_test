defmodule WaltUi.Enrichment.PttWrapper do
  @moduledoc """
  Adjusts Move Scores based on data quality and financial indicators.

  Business rules:
  1. Address mismatch: -50% reduction if Faraday and Trestle addresses don't match
  2. Renter: -20% reduction if contact is a renter
  3. Reductions stack multiplicatively
  4. Minimum Move Score is 1 for positive values, 0 stays 0
  """

  alias CQRS.Enrichments.Data.ProviderData

  @spec adjust(integer() | float() | nil, [ProviderData.t()]) :: integer()
  def adjust(nil, _provider_data_list), do: 0
  def adjust(0, _provider_data_list), do: 0

  def adjust(ptt, provider_data_list) when is_float(ptt) do
    ptt |> round() |> adjust(provider_data_list)
  end

  def adjust(ptt, provider_data_list) do
    # Extract provider data
    faraday_data = find_provider_data(provider_data_list, "faraday")
    trestle_data = find_provider_data(provider_data_list, "trestle")

    # Apply reductions
    ptt
    |> apply_address_mismatch_reduction(faraday_data, trestle_data)
    |> apply_renter_reduction(faraday_data)
    |> enforce_minimum()
  end

  defp find_provider_data(provider_data_list, provider_type) do
    Enum.find(provider_data_list, fn
      %ProviderData{provider_type: ^provider_type} -> true
      _ -> false
    end)
  end

  defp apply_address_mismatch_reduction(ptt, nil, _), do: ptt
  defp apply_address_mismatch_reduction(ptt, _, nil), do: ptt

  defp apply_address_mismatch_reduction(ptt, faraday_data, trestle_data) do
    if address_mismatch?(faraday_data, trestle_data) do
      ptt * 0.5
    else
      ptt
    end
  end

  defp address_mismatch?(%ProviderData{enrichment_data: faraday}, %ProviderData{
         enrichment_data: trestle
       }) do
    # Compare street_1, city, state, zip (NOT street_2)
    faraday_address = normalize_address(faraday)
    trestle_address = normalize_address(trestle)

    faraday_address != trestle_address
  end

  defp normalize_address(data) when is_map(data) do
    %{
      street_1: normalize_field(data[:street_1]),
      city: normalize_field(data[:city]),
      state: normalize_field(data[:state]),
      zip: normalize_field(data[:zip])
    }
  end

  defp normalize_address(_), do: %{street_1: nil, city: nil, state: nil, zip: nil}

  defp normalize_field(value) when is_binary(value) do
    value
    |> String.downcase()
    |> String.trim()
  end

  defp normalize_field(value), do: value

  defp apply_renter_reduction(ptt, %ProviderData{enrichment_data: data}) when is_map(data) do
    data
    |> CQRS.Utils.get(:homeowner_status)
    |> renter?()
    |> case do
      true -> ptt * 0.8
      false -> ptt
    end
  end

  defp apply_renter_reduction(ptt, _), do: ptt

  defp renter?("Definite Renter"), do: true
  defp renter?("Probable Renter"), do: true
  defp renter?(_), do: false

  defp enforce_minimum(adjusted_ptt) do
    adjusted_ptt |> round() |> max(1)
  end
end
