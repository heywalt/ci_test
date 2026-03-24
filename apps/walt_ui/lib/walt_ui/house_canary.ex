defmodule WaltUi.HouseCanary do
  @moduledoc """
  Context module for querying HouseCanary property data.

  Used as a post-enrichment confidence layer to validate address and
  ownership data returned by the Trestle/Faraday enrichment pipeline.
  """
  import Ecto.Query

  alias WaltUi.HouseCanary.Property

  @doc """
  Finds a property by address components.

  Returns the first matching property or nil.
  """
  def find_by_address(street_number, street_name, city, state, zipcode) do
    Property
    |> where(
      [p],
      p.address_street_number == ^street_number and
        p.address_street_name == ^street_name and
        p.city == ^city and
        p.state == ^state and
        p.zipcode == ^zipcode
    )
    |> limit(1)
    |> HouseCanaryRepo.one()
  end

  @doc """
  Finds properties by zipcode.

  Useful for broader candidate searches before applying more
  detailed matching logic in Elixir.
  """
  def find_by_zipcode(zipcode) do
    Property
    |> where([p], p.zipcode == ^zipcode)
    |> HouseCanaryRepo.all()
  end

  @doc """
  Finds properties by owner name.
  """
  def find_by_owner_name(owner_name) do
    Property
    |> where([p], p.owner_name == ^owner_name)
    |> HouseCanaryRepo.all()
  end

  @doc """
  Finds properties where the given last name matches a lien borrower.
  """
  def find_by_borrower_last_name(last_name) do
    Property
    |> where(
      [p],
      p.lien1_borrower1_last_name == ^last_name or
        p.lien2_borrower1_last_name == ^last_name
    )
    |> HouseCanaryRepo.all()
  end

  @doc """
  Looks up a property by address and checks whether the owner name matches
  the given contact name. Returns a map with the property (if found) and
  a confidence assessment.

  ## Confidence levels

    * `:high` - owner name matches and property is owner-occupied
    * `:medium` - owner name matches but property is not owner-occupied
    * `:low` - property found but owner name does not match
    * `:none` - no property found at the given address
  """
  def validate_address(street_number, street_name, city, state, zipcode, contact_name) do
    case find_by_address(street_number, street_name, city, state, zipcode) do
      nil ->
        %{property: nil, confidence: :none}

      property ->
        owner_matches = name_matches?(property.owner_name, contact_name)
        owner_occupied = property.owner_occupied_yn == "Y"

        confidence =
          cond do
            owner_matches and owner_occupied -> :high
            owner_matches -> :medium
            true -> :low
          end

        %{property: property, confidence: confidence}
    end
  end

  defp name_matches?(nil, _contact_name), do: false
  defp name_matches?(_owner_name, nil), do: false
  defp name_matches?("", _contact_name), do: false
  defp name_matches?(_owner_name, ""), do: false

  defp name_matches?(owner_name, contact_name) do
    owner_parts = split_name(owner_name)
    contact_parts = split_name(contact_name)
    name_score(owner_parts, contact_parts) >= 50
  end

  defp split_name(name) do
    name
    |> String.trim()
    |> String.downcase()
    |> String.split(~r/\s+/, trim: true)
  end

  # We don't know whether HouseCanary formats owner_name as "LAST FIRST"
  # or "FIRST LAST", so we check both orderings when comparing name parts.
  defp name_score(owner_parts, contact_parts) do
    owner_pairs = name_pairs(owner_parts)
    contact_pairs = name_pairs(contact_parts)

    for {o1, o2} <- owner_pairs, {c1, c2} <- contact_pairs, reduce: 0 do
      best ->
        score =
          cond do
            exact?(o1, c1) && exact?(o2, c2) -> 100
            exact?(o1, c1) || exact?(o2, c2) -> 75
            jaro?(o1, c1) || jaro?(o2, c2) -> 50
            true -> 0
          end

        max(best, score)
    end
  end

  # Given ["john", "adam", "smith"], returns [{"john", "smith"}]
  # Given ["john", "smith"], returns [{"john", "smith"}, {"smith", "john"}]
  # This lets us compare first/last regardless of name order.
  defp name_pairs([first | rest]) when length(rest) >= 1 do
    last = List.last(rest)
    [{first, last}, {last, first}]
  end

  defp name_pairs([single]), do: [{single, nil}]
  defp name_pairs([]), do: []

  defp exact?(a, b) when is_nil(a) or is_nil(b), do: false
  defp exact?(a, b), do: a == b

  defp jaro?(a, b) when is_nil(a) or is_nil(b), do: false
  defp jaro?(a, b), do: String.jaro_distance(a, b) >= 0.8
end
