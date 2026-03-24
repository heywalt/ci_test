defmodule WaltUi.Projectors.Enrichment do
  @moduledoc false

  use Commanded.Projections.Ecto,
    application: CQRS,
    repo: Repo,
    name: __MODULE__,
    start_from: :current,
    consistency: :strong

  require Logger

  alias CQRS.Enrichments.Events
  alias CQRS.Enrichments.Events.EnrichmentComposed
  alias CQRS.Enrichments.Events.EnrichmentReset
  alias WaltUi.Projections.Enrichment

  project %Events.EnrichedWithFaraday{} = evt, _metadata, fn multi ->
    attrs = build_enrichment_attrs_from_faraday(evt)

    multi
    |> Ecto.Multi.one(:enrichment, fn _ -> from e in Enrichment, where: e.id == ^evt.id end)
    |> Ecto.Multi.insert_or_update(:upsert, &upsert_record(&1, attrs))
  end

  project %EnrichmentComposed{} = evt, _metadata, fn multi ->
    attrs = build_enrichment_attrs_from_composed(evt)

    Logger.info("Composed enrichment projection",
      event_id: evt.id,
      projection_status: "success",
      module: __MODULE__
    )

    multi
    |> Ecto.Multi.one(:enrichment, fn _ -> from e in Enrichment, where: e.id == ^evt.id end)
    |> Ecto.Multi.insert_or_update(:upsert, &upsert_record(&1, attrs))
  end

  project %EnrichmentReset{} = event, _metadata, fn multi ->
    Ecto.Multi.delete_all(
      multi,
      :delete_enrichment,
      from(e in Enrichment, where: e.id == ^event.id)
    )
  end

  @impl Commanded.Event.Handler
  def error(error, event, _ctx) do
    Logger.error("Error projecting Enrichment data",
      event_id: event.id,
      event_type: event.__struct__,
      module: __MODULE__,
      reason: inspect(error)
    )

    :skip
  end

  defp upsert_record(multi, attrs) do
    record = multi.enrichment || %Enrichment{}
    Enrichment.changeset(record, attrs)
  end

  defp build_enrichment_attrs_from_faraday(event) do
    %{
      id: event.id,
      full_name: "#{event.first_name} #{event.last_name}",
      first_name: event.first_name,
      last_name: event.last_name,
      date_of_birth: format_date(event.date_of_birth),
      age: age_range(event.age),
      education: event.education,
      marital_status: event.marital_status,
      date_newly_married: format_date(event.date_newly_married),
      date_newly_single: format_date(event.date_newly_single),
      occupation: event.occupation,
      home_equity_loan_date: format_date(event.date_of_home_equity_loan),
      home_equity_loan_amount: large_range(event.home_equity_loan_amount),
      latest_mortgage_amount: large_range(event.latest_mortgage_amount),
      latest_mortgage_date: format_date(event.date_of_latest_mortgage),
      latest_mortgage_interest_rate: interest_rate(event.latest_mortgage_interest_rate),
      percent_equity: percent_range(event.percent_equity, "Negative Equity"),
      household_income: household_income(event.household_income),
      income_change_date: format_date(event.date_of_income_change),
      liquid_resources: liquidity(event.liquid_resources),
      net_worth: large_range(event.net_worth),
      affluency: to_string(event.affluency),
      homeowner_status: homeowner_status_mapping(event.homeowner_status),
      mortgage_liability: large_range(event.mortgage_liability),
      lot_size_in_acres: lot_acres(event.lot_size_in_acres),
      probability_to_have_hot_tub: percent_range(event.probability_to_have_hot_tub),
      target_home_market_value: large_range(event.target_home_market_value),
      property_type: event.property_type,
      number_of_bedrooms: small_range(event.number_of_bedrooms),
      number_of_bathrooms: small_range(event.number_of_bathrooms),
      year_built: to_string(event.year_built),
      length_of_residence: residence(event.length_of_residence),
      average_commute_time: commute_time(event.average_commute_time),
      has_basement: event.has_basement,
      basement_area: to_square_feet(event.basement_area),
      garage_spaces: small_range(event.garage_spaces),
      living_area: to_square_feet(event.living_area),
      lot_area: lot_area(event.lot_area),
      has_pool: event.has_pool,
      zoning_type: event.zoning_type,
      is_twitter_user: event.is_twitter_user,
      is_facebook_user: event.is_facebook_user,
      is_instagram_user: event.is_instagram_user,
      is_active_on_social_media: event.is_active_on_social_media,
      likes_travel: event.likes_travel,
      has_children_in_household: event.has_children_in_household,
      number_of_children: small_range(event.number_of_children),
      first_child_birthdate: format_date(event.date_of_first_childbirth),
      has_pet: event.has_pet,
      interest_in_grandchildren: event.interest_in_grandchildren,
      date_empty_nester: format_date(event.date_empty_nester),
      date_retired: format_date(event.date_retired),
      vehicle_make: event.vehicle_make,
      vehicle_model: event.vehicle_model,
      vehicle_year: to_string(event.vehicle_year)
    }
  end

  defp build_enrichment_attrs_from_composed(event) do
    data = event.composed_data

    # Build full_name from first_name and last_name
    full_name =
      case {data[:first_name], data[:last_name]} do
        {nil, nil} -> nil
        {first, nil} -> first
        {nil, last} -> last
        {first, last} -> "#{first} #{last}"
      end

    %{
      id: event.id,
      full_name: full_name,
      first_name: data[:first_name],
      last_name: data[:last_name],
      date_of_birth: format_date(data[:date_of_birth]),
      age: age_range(data[:age]),
      education: data[:education],
      marital_status: data[:marital_status],
      date_newly_married: format_date(data[:date_newly_married]),
      date_newly_single: format_date(data[:date_newly_single]),
      occupation: data[:occupation],
      home_equity_loan_date: format_date(data[:date_of_home_equity_loan]),
      home_equity_loan_amount: large_range(data[:home_equity_loan_amount]),
      latest_mortgage_amount: large_range(data[:latest_mortgage_amount]),
      latest_mortgage_date: format_date(data[:date_of_latest_mortgage]),
      latest_mortgage_interest_rate: interest_rate(data[:latest_mortgage_interest_rate]),
      percent_equity: percent_range(data[:percent_equity], "Negative Equity"),
      household_income: household_income(data[:household_income]),
      income_change_date: format_date(data[:date_of_income_change]),
      liquid_resources: liquidity(data[:liquid_resources]),
      net_worth: large_range(data[:net_worth]),
      affluency: to_string(data[:affluency]),
      homeowner_status: homeowner_status_mapping(data[:homeowner_status]),
      mortgage_liability: large_range(data[:mortgage_liability]),
      lot_size_in_acres: lot_acres(data[:lot_size_in_acres]),
      probability_to_have_hot_tub: percent_range(data[:probability_to_have_hot_tub]),
      target_home_market_value: large_range(data[:target_home_market_value]),
      property_type: data[:property_type],
      number_of_bedrooms: small_range(data[:number_of_bedrooms]),
      number_of_bathrooms: small_range(data[:number_of_bathrooms]),
      year_built: to_string(data[:year_built]),
      length_of_residence: residence(data[:length_of_residence]),
      average_commute_time: commute_time(data[:average_commute_time]),
      has_basement: data[:has_basement],
      basement_area: to_square_feet(data[:basement_area]),
      garage_spaces: small_range(data[:garage_spaces]),
      living_area: to_square_feet(data[:living_area]),
      lot_area: lot_area(data[:lot_area]),
      has_pool: data[:has_pool],
      zoning_type: data[:zoning_type],
      is_twitter_user: data[:is_twitter_user],
      is_facebook_user: data[:is_facebook_user],
      is_instagram_user: data[:is_instagram_user],
      is_active_on_social_media: data[:is_active_on_social_media],
      likes_travel: data[:likes_travel],
      has_children_in_household: data[:has_children_in_household],
      number_of_children: small_range(data[:number_of_children]),
      first_child_birthdate: format_date(data[:date_of_first_childbirth]),
      has_pet: data[:has_pet],
      interest_in_grandchildren: data[:interest_in_grandchildren],
      date_empty_nester: format_date(data[:date_empty_nester]),
      date_retired: format_date(data[:date_retired]),
      vehicle_make: data[:vehicle_make],
      vehicle_model: data[:vehicle_model],
      vehicle_year: to_string(data[:vehicle_year])
    }
  end

  defp age_range(nil), do: nil
  # Trestle age ranges are already strings
  defp age_range(val) when is_binary(val), do: val
  defp age_range(val) when is_float(val), do: age_range(trunc(val))
  defp age_range(val) when val in 1..17, do: "1-17"
  defp age_range(val) when val in 18..24, do: "18-24"
  defp age_range(val) when val in 25..34, do: "25-34"
  defp age_range(val) when val in 35..44, do: "35-44"
  defp age_range(val) when val in 45..54, do: "45-54"
  defp age_range(val) when val in 55..64, do: "55-64"
  defp age_range(_val), do: "65+"

  defp commute_time(nil), do: nil
  defp commute_time(val) when is_float(val), do: commute_time(trunc(val))
  defp commute_time(val) when val in 0..5, do: "0-5"
  defp commute_time(val) when val in 5..10, do: "5-10"
  defp commute_time(val) when val in 10..20, do: "10-20"
  defp commute_time(val) when val in 20..30, do: "20-30"
  defp commute_time(val) when val in 30..40, do: "30-40"
  defp commute_time(val) when val in 40..50, do: "40-50"
  defp commute_time(val) when val in 50..60, do: "50-60"
  defp commute_time(val) when val > 60, do: "60+"

  defp format_date(val) when is_binary(val) do
    val
    |> String.split("-")
    |> Enum.map(&String.to_integer/1)
    |> then(fn [year, month, day] -> [month, day, year] end)
    |> Enum.join("/")
  rescue
    _ -> nil
  end

  defp format_date(_val), do: nil

  defp interest_rate(val) when is_float(val) do
    val
    |> ceil()
    |> interest_rate()
  end

  defp interest_rate(nil), do: nil
  defp interest_rate(val) when val in 0..1, do: "0-1%"
  defp interest_rate(val) when val in 1..2, do: "1-2%"
  defp interest_rate(val) when val in 2..3, do: "2-3%"
  defp interest_rate(val) when val in 3..4, do: "3-4%"
  defp interest_rate(val) when val in 4..5, do: "4-5%"
  defp interest_rate(val) when val in 5..10, do: "5-10%"
  defp interest_rate(val) when val in 10..15, do: "10-15%"
  defp interest_rate(val) when val > 15, do: "15%+"

  defp percent_range(val, neg_range \\ "0%-10%")
  defp percent_range(nil, _neg), do: nil
  defp percent_range(val, neg_range) when is_float(val), do: percent_range(trunc(val), neg_range)
  defp percent_range(val, neg_range) when val < 0, do: neg_range
  defp percent_range(val, _neg) when val in 0..10, do: "0%-10%"
  defp percent_range(val, _neg) when val in 10..20, do: "10%-20%"
  defp percent_range(val, _neg) when val in 20..30, do: "20%-30%"
  defp percent_range(val, _neg) when val in 30..40, do: "30%-40%"
  defp percent_range(val, _neg) when val in 40..50, do: "40%-50%"
  defp percent_range(val, _neg) when val in 50..60, do: "50%-60%"
  defp percent_range(val, _neg) when val in 60..70, do: "60%-70%"
  defp percent_range(val, _neg) when val in 70..80, do: "70%-80%"
  defp percent_range(val, _neg) when val in 80..90, do: "80%-90%"
  defp percent_range(val, _neg) when val in 90..100, do: "90%-100%"
  defp percent_range(val, _neg) when val > 100, do: "100%+"

  defp household_income(nil), do: nil
  defp household_income(val) when is_float(val), do: household_income(trunc(val))
  defp household_income(val) when val < 200_000, do: "$#{floor(val / 10000) * 10}k+"
  defp household_income(val) when val in 200_001..250_000, do: "$200k+"
  defp household_income(val) when val in 250_001..300_000, do: "$250k+"
  defp household_income(val) when val in 300_001..350_000, do: "$300k+"
  defp household_income(val) when val in 350_001..400_000, do: "$350k+"
  defp household_income(val) when val in 400_001..450_000, do: "$400k+"
  defp household_income(val) when val in 450_001..500_000, do: "$450k+"
  defp household_income(val) when val in 500_001..600_000, do: "$500k+"
  defp household_income(val) when val in 600_001..700_000, do: "$600k+"
  defp household_income(val) when val in 700_001..800_000, do: "$700k+"
  defp household_income(val) when val in 800_001..900_000, do: "$800k+"
  defp household_income(val) when val in 900_001..1_000_000, do: "$900k+"
  defp household_income(_val), do: "$1M+"

  defp large_range(nil), do: nil
  defp large_range(val) when is_float(val), do: large_range(trunc(val))
  defp large_range(val) when val in 0..50_000, do: "$0-$50k"
  defp large_range(val) when val in 50_001..100_000, do: "$50k-$100k"
  defp large_range(val) when val in 100_001..150_000, do: "$100k-$150k"
  defp large_range(val) when val in 150_001..200_000, do: "$150k-$200k"
  defp large_range(val) when val in 200_001..250_000, do: "$200k-$250k"
  defp large_range(val) when val in 250_001..300_000, do: "$250k-$300k"
  defp large_range(val) when val in 300_001..350_000, do: "$300k-$350k"
  defp large_range(val) when val in 350_001..400_000, do: "$350k-$400k"
  defp large_range(val) when val in 400_001..450_000, do: "$400k-$450k"
  defp large_range(val) when val in 450_001..500_000, do: "$450k-$500k"
  defp large_range(val) when val in 500_001..600_000, do: "$500k-$600k"
  defp large_range(val) when val in 600_001..700_000, do: "$600k-$700k"
  defp large_range(val) when val in 700_001..800_000, do: "$700k-$800k"
  defp large_range(val) when val in 800_001..900_000, do: "$800k-$900k"
  defp large_range(val) when val in 900_001..1_000_000, do: "$900k-$1M"
  defp large_range(_val), do: "$1M+"

  defp liquidity(nil), do: nil
  defp liquidity("Less than $500"), do: "<$500"
  defp liquidity("$100000 or more"), do: "$100k+"

  defp liquidity(val) do
    val
    |> String.split(" - ")
    |> Enum.map_join(" - ", fn val ->
      val
      |> String.replace("$", "")
      |> String.to_integer()
      |> Kernel./(100)
      |> trunc()
      |> then(&"$#{&1}k")
    end)
  end

  defp lot_acres(val) when is_float(val) do
    val
    |> Kernel.*(100)
    |> trunc()
    |> lot_acres()
  end

  defp lot_acres(nil), do: nil
  defp lot_acres(val) when val in 0..25, do: "0-0.25"
  defp lot_acres(val) when val in 26..50, do: "0.25-0.5"
  defp lot_acres(val) when val in 51..100, do: "0.5-1"
  defp lot_acres(val) when val in 101..200, do: "1-2"
  defp lot_acres(val) when val in 201..300, do: "2-3"
  defp lot_acres(val) when val in 301..400, do: "3-4"
  defp lot_acres(val) when val in 401..500, do: "4-5"
  defp lot_acres(_val), do: "5+"

  defp lot_area(val) when is_integer(val) do
    val
    |> Kernel./(4047)
    |> Float.round(2)
    |> Float.to_string()
  end

  defp lot_area(val) when is_float(val) do
    val
    |> trunc()
    |> lot_area()
  end

  defp lot_area(_val), do: nil

  defp small_range(nil), do: nil
  defp small_range(val) when is_float(val), do: small_range(trunc(val))
  defp small_range(val) when val in 0..2, do: "0-2"
  defp small_range(val) when val in [3, 4], do: "3-4"
  defp small_range(val) when val in [5, 6], do: "5-6"
  defp small_range(val) when val in [7, 8], do: "7-8"
  defp small_range(_val), do: "9+"

  defp to_square_feet(nil), do: nil

  defp to_square_feet(val) when is_float(val) do
    val
    |> trunc()
    |> to_square_feet()
  end

  defp to_square_feet(val) when is_binary(val) do
    val
    |> String.to_integer()
    |> Kernel.*(10.76391)
    |> round()
    |> Integer.to_string()
  end

  defp to_square_feet(val) when is_integer(val) do
    val
    |> Kernel.*(10.76391)
    |> round()
    |> Integer.to_string()
  end

  defp residence(nil), do: nil
  defp residence(val) when is_float(val), do: residence(trunc(val))
  defp residence(val) when val in 0..5, do: "0-5"
  defp residence(val) when val in 5..10, do: "5-10"
  defp residence(val) when val in 10..15, do: "10-15"
  defp residence(val) when val in 15..20, do: "15-20"
  defp residence(val) when val in 20..25, do: "20-25"
  defp residence(val) when val in 25..30, do: "25-30"
  defp residence(val) when val in 30..35, do: "30-35"
  defp residence(val) when val in 35..40, do: "35-40"
  defp residence(val) when val in 40..45, do: "40-45"
  defp residence(val) when val in 45..50, do: "45-50"
  defp residence(val) when val in 50..55, do: "50-55"
  defp residence(val) when val in 55..60, do: "55-60"
  defp residence(val) when val in 60..65, do: "60-65"
  defp residence(val) when val > 65, do: "65+"

  defp homeowner_status_mapping(val) when is_binary(val), do: val
  defp homeowner_status_mapping(_), do: nil
end
