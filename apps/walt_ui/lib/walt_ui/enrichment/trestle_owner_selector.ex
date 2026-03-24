defmodule WaltUi.Enrichment.TrestleOwnerSelector do
  @moduledoc """
  Selects the best matching owner from a list of Trestle owners based on name similarity.
  """

  require Logger

  @doc """
  Selects the best owner from a list based on name hint matching.
  Returns the owner with the highest match score, or falls back to the first owner.
  Returns nil if the owners list is empty or nil.
  """
  def select_best_owner(nil, _name_hint, _enrichment_id), do: nil
  def select_best_owner([], _name_hint, _enrichment_id), do: nil

  def select_best_owner([owner], _name_hint, enrichment_id) do
    Logger.info("Owner selected from Trestle data",
      event_id: enrichment_id,
      selection_score: 0,
      match_type: "single_owner",
      owner_count: 1,
      fallback_used: false,
      module: __MODULE__
    )

    owner
  end

  def select_best_owner(owners, name_hint, enrichment_id)
      when is_nil(name_hint) or name_hint == "" do
    owner = List.first(owners)

    Logger.info("Owner selected from Trestle data",
      event_id: enrichment_id,
      selection_score: 0,
      match_type: "no_name_hint",
      owner_count: length(owners),
      fallback_used: false,
      module: __MODULE__
    )

    owner
  end

  def select_best_owner(owners, name_hint, enrichment_id) do
    name_hint = String.trim(name_hint)

    {owner, score} =
      owners
      |> Enum.map(fn owner ->
        score = score_owner_name_match(owner, name_hint)
        {owner, score}
      end)
      |> Enum.max_by(fn {_owner, score} -> score end)

    {selected_owner, fallback_used} =
      if score >= 50 do
        {owner, false}
      else
        {List.first(owners), true}
      end

    match_type = determine_match_type(score)

    Logger.info("Owner selected from Trestle data",
      event_id: enrichment_id,
      selection_score: score,
      match_type: match_type,
      owner_count: length(owners),
      fallback_used: fallback_used,
      module: __MODULE__
    )

    selected_owner
  end

  @doc """
  Scores how well an owner's name matches the given name hint.
  Returns a score from 0 to 100.
  - 100: Exact match (first and last name)
  - 75: Partial match (first OR last name)
  - 50: Fuzzy match (similar names)
  - 0: No match
  """
  def score_owner_name_match(nil, _name_hint), do: 0
  def score_owner_name_match(_owner, nil), do: 0
  def score_owner_name_match(_owner, ""), do: 0

  def score_owner_name_match(owner, name_hint) do
    owner_name = extract_owner_name(owner)
    hint_parts = parse_name_hint(name_hint)

    case {owner_name, hint_parts} do
      {nil, _} ->
        0

      {_, nil} ->
        0

      {{owner_first, owner_last}, {hint_first, hint_last}} ->
        primary_score = calculate_score(owner_first, owner_last, hint_first, hint_last)

        # If primary score is perfect, return it; otherwise check alternate names
        if primary_score == 100 do
          primary_score
        else
          alternate_score = score_alternate_names(owner, hint_first, hint_last)
          max(primary_score, alternate_score)
        end
    end
  end

  defp extract_owner_name(owner) when is_map(owner) do
    case owner do
      %{"firstname" => first, "lastname" => last} ->
        {normalize_name(first), normalize_name(last)}

      %{"name" => %{"first" => first, "last" => last}} ->
        {normalize_name(first), normalize_name(last)}

      _ ->
        nil
    end
  end

  defp extract_owner_name(_), do: nil

  defp parse_name_hint(name_hint) do
    case String.split(String.trim(name_hint), " ", trim: true) do
      [] -> nil
      [single_name] -> {normalize_name(single_name), nil}
      [first | rest] -> {normalize_name(first), normalize_name(Enum.join(rest, " "))}
    end
  end

  defp normalize_name(nil), do: nil
  defp normalize_name(""), do: nil

  defp normalize_name(name) when is_binary(name) do
    name
    |> String.trim()
    |> String.downcase()
    |> case do
      "" -> nil
      normalized -> normalized
    end
  end

  defp normalize_name(_), do: nil

  defp calculate_score(owner_first, owner_last, hint_first, hint_last) do
    cond do
      exact_full_name_match?(owner_first, owner_last, hint_first, hint_last) -> 100
      single_hint_exact_match?(owner_first, owner_last, hint_first, hint_last) -> 75
      partial_exact_match?(owner_first, owner_last, hint_first, hint_last) -> 75
      any_fuzzy_match?(owner_first, owner_last, hint_first, hint_last) -> 50
      true -> 0
    end
  end

  defp exact_full_name_match?(owner_first, owner_last, hint_first, hint_last) do
    exact_match?(owner_first, hint_first) && exact_match?(owner_last, hint_last)
  end

  defp single_hint_exact_match?(owner_first, owner_last, hint_first, hint_last) do
    is_nil(hint_last) &&
      (exact_match?(owner_first, hint_first) || exact_match?(owner_last, hint_first))
  end

  defp partial_exact_match?(owner_first, owner_last, hint_first, hint_last) do
    exact_match?(owner_first, hint_first) || exact_match?(owner_last, hint_last)
  end

  defp any_fuzzy_match?(owner_first, owner_last, hint_first, hint_last) do
    fuzzy_match?(owner_first, hint_first) ||
      fuzzy_match?(owner_last, hint_last) ||
      cross_fuzzy_match?(owner_first, owner_last, hint_first, hint_last)
  end

  defp cross_fuzzy_match?(_owner_first, _owner_last, _hint_first, nil), do: false

  defp cross_fuzzy_match?(owner_first, owner_last, hint_first, hint_last) do
    fuzzy_match?(owner_first, hint_last) || fuzzy_match?(owner_last, hint_first)
  end

  defp exact_match?(nil, _), do: false
  defp exact_match?(_, nil), do: false
  defp exact_match?(name1, name2), do: name1 == name2

  defp fuzzy_match?(nil, _), do: false
  defp fuzzy_match?(_, nil), do: false

  defp fuzzy_match?(name1, name2) do
    # Simple fuzzy matching based on:
    # 1. One name contains the other
    # 2. Levenshtein distance is small relative to string length
    String.contains?(name1, name2) ||
      String.contains?(name2, name1) ||
      similar_enough?(name1, name2)
  end

  defp similar_enough?(name1, name2) do
    distance = String.jaro_distance(name1, name2)
    distance >= 0.8
  end

  defp score_alternate_names(owner, hint_first, hint_last) do
    case owner["alternate_names"] do
      names when is_list(names) ->
        names
        |> Enum.map(&parse_alternate_name/1)
        |> Enum.reject(&is_nil/1)
        |> Enum.map(fn {alt_first, alt_last} ->
          calculate_alternate_score(alt_first, alt_last, hint_first, hint_last)
        end)
        |> Enum.max(fn -> 0 end)

      _ ->
        0
    end
  end

  defp parse_alternate_name(name) when is_binary(name) do
    case String.split(String.trim(name), " ", trim: true) do
      [] -> nil
      [single_name] -> {normalize_name(single_name), nil}
      [first | rest] -> {normalize_name(first), normalize_name(Enum.join(rest, " "))}
    end
  end

  defp parse_alternate_name(_), do: nil

  defp calculate_alternate_score(alt_first, alt_last, hint_first, hint_last) do
    cond do
      exact_alternate_full_match?(alt_first, alt_last, hint_first, hint_last) -> 85
      single_hint_alternate_match?(alt_first, alt_last, hint_first, hint_last) -> 60
      partial_alternate_match?(alt_first, alt_last, hint_first, hint_last) -> 60
      any_fuzzy_match?(alt_first, alt_last, hint_first, hint_last) -> 50
      true -> 0
    end
  end

  defp exact_alternate_full_match?(alt_first, alt_last, hint_first, hint_last) do
    exact_match?(alt_first, hint_first) && alternate_last_match?(alt_last, hint_last)
  end

  defp single_hint_alternate_match?(alt_first, alt_last, hint_first, hint_last) do
    is_nil(hint_last) &&
      (exact_match?(alt_first, hint_first) || alternate_last_match?(alt_last, hint_first))
  end

  defp partial_alternate_match?(alt_first, alt_last, hint_first, hint_last) do
    exact_match?(alt_first, hint_first) || alternate_last_match?(alt_last, hint_last)
  end

  # Handle alternate last names that may contain middle names/initials
  defp alternate_last_match?(alt_last, hint_last) do
    cond do
      exact_match?(alt_last, hint_last) ->
        true

      # Check if the hint last name appears at the end of the alternate last name
      # e.g., "a sedlak" contains "sedlak" at the end
      alt_last && hint_last && String.ends_with?(alt_last, hint_last) ->
        true

      true ->
        false
    end
  end

  defp determine_match_type(score) do
    cond do
      score == 100 -> "exact"
      score >= 85 -> "alternate_exact"
      score == 75 -> "partial"
      score >= 60 -> "alternate_partial"
      score == 50 -> "fuzzy"
      true -> "no_match"
    end
  end
end
