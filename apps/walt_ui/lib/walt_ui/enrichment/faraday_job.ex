defmodule WaltUi.Enrichment.FaradayJob do
  @moduledoc false

  use Oban.Worker, queue: :faraday, max_attempts: 10

  require Logger

  alias CQRS.Enrichments.Commands.CompleteProviderEnrichment
  alias Repo.Types.TenDigitPhone
  alias WaltUi.Enrichment.Faraday

  @http_key_mapping %{
    "fdy_attribute_fig_affluence_affluent" => :affluency,
    "fdy_attribute_fig_affluence_highly_affluent" => :affluency,
    "fdy_attribute_fig_mortgage_liability" => :mortgage_liability,
    "fdy_attribute_fig_life_other_grandchildren_all" => :interest_in_grandchildren,
    "fdy_attribute_fig_household_size" => :household_size,
    "fdy_attribute_fig_garage_spaces" => :garage_spaces,
    "fdy_attribute_fig_pet_any" => :has_pet,
    "fdy_outcome_2cac2e5e_27d4_4045_99ef_0338f007b8e6_propensity_probability" =>
      :propensity_to_transact,
    "fdy_attribute_fig_household_income" => :household_income,
    "fdy_attribute_fig_latest_mortgage_date" => :date_of_latest_mortgage,
    "fdy_attribute_fig_liquid_resources" => :liquid_resources,
    "fdy_attribute_fig_net_worth" => :net_worth,
    "fdy_attribute_fig_property_type" => :property_type,
    "fdy_attribute_fig_marital_status" => :marital_status,
    "fdy_outcome_2cac2e5e_27d4_4045_99ef_0338f007b8e6_propensity_percentile" =>
      :propensity_percentile,
    "city" => :city,
    "fdy_attribute_fig_adults" => :number_of_adults,
    "latitude" => :latitude,
    "fdy_attribute_fig_pool" => :has_pool,
    "fdy_attribute_fig_credit_rating" => :credit_rating,
    "fdy_attribute_fig_bld_val" => :building_value,
    "fdy_attribute_fig_basement" => :has_basement,
    "fdy_attribute_fig_trigger_change_date_income" => :date_of_income_change,
    "fdy_attribute_fig_trigger_date_newly_married" => :date_newly_married,
    "match_type" => :match_type,
    "fdy_attribute_fig_trigger_date_newly_single" => :date_newly_single,
    "fdy_attribute_fig_trigger_date_empty_nester" => :date_empty_nester,
    "postcode" => :postcode,
    "fdy_attribute_fig_baths" => :number_of_bathrooms,
    "fdy_attribute_fig_number_of_children" => :number_of_children,
    "phone" => :phone,
    "fdy_attribute_fig_child_1_birthdate" => :first_child_birthdate,
    "fdy_attribute_fig_cl_avg_commute_time" => :average_commute_time,
    "fdy_attribute_fig_latest_mortgage_interest_rate" => :latest_mortgage_interest_rate,
    "fdy_attribute_fig_children_in_household" => :has_children_in_household,
    "fdy_attribute_fig_beds" => :number_of_bedrooms,
    "fdy_attribute_fig_living_area" => :living_area,
    "fdy_attribute_fig_vehicle_year" => :vehicle_year,
    "fdy_attribute_fig_date_of_birth" => :date_of_birth,
    "fdy_attribute_fig_homeowner_status" => :homeowner_status,
    "longitude" => :longitude,
    "fdy_attribute_fig_zoning_type" => :zoning_type,
    "fdy_attribute_fig_occupation" => :occupation,
    "fdy_attribute_fig_wealth_resources" => :wealth_resources,
    "fdy_attribute_fig_latest_mortgage" => :latest_mortgage_amount,
    "fdy_attribute_fig_percent_equity" => :percent_equity,
    "fdy_attribute_fig_pre_mover_rank" => :premover_rank,
    "fdy_attribute_fig_vehicle_make" => :vehicle_make,
    "fdy_attribute_fig_basement_area" => :basement_area,
    "fdy_attribute_fig_travel" => :likes_travel,
    "fdy_attribute_fig_education" => :education,
    "fdy_attribute_fig_trigger_date_retired" => :date_retired,
    "fdy_attribute_fig_age" => :age,
    "fdy_attribute_fig_lot_area" => :lot_area,
    "house_number_and_street" => :address,
    "person_last_name" => :last_name,
    "fdy_attribute_fig_year_built" => :year_built,
    "state" => :state,
    "fdy_attribute_fig_length_of_residence" => :length_of_residence,
    "person_first_name" => :first_name,
    "fdy_attribute_fig_vehicle_model" => :vehicle_model,
    "fdy_attribute_fig_life_media_twitter_all" => :is_twitter_user,
    "fdy_attribute_fig_life_media_instagram_all" => :is_instagram_user,
    "fdy_attribute_fig_life_media_facebook_all" => :is_facebook_user,
    "fdy_attribute_fig_home_equity_loan_amount" => :home_equity_loan_amount,
    "fdy_attribute_fig_target_home_market_value_2_0" => :target_home_market_value,
    "fdy_attribute_fig_life_social_media_any" => :is_active_on_social_media,
    "fdy_attribute_fig_property_lot_size_in_acres_actual" => :lot_size_in_acres,
    "fdy_attribute_fig_mt_hot_tub_spa_jacuzzi_owners" => :probability_to_have_hot_tub,
    "fdy_attribute_fig_home_equity_loan_date" => :date_of_home_equity_loan,
    "email" => :email
  }

  @age_range_tolerance 3

  @impl true
  def perform(%{args: %{"event" => event}}) do
    attrs = normalize_event(event)
    Logger.metadata(event_id: attrs.id, module: __MODULE__)

    perform_new_structure(attrs)
  end

  defp perform_new_structure(attrs) do
    with {:ok, id_sets} <- make_identity_sets_new(attrs),
         {:ok, body} <- Faraday.fetch_by_identity_sets(id_sets),
         :ok <- confirm_match_new(body, attrs),
         :ok <- dispatch_completion(body, attrs) do
      Logger.info("Found enrichment via Faraday identity sets")
    else
      {:error, :dispatch} ->
        {:cancel, :dispatch_error}

      {:error, :no_match_type} ->
        Logger.info("Faraday enrichment does not include match_type")
        dispatch_error_completion(attrs, %{reason: :no_match_type})
        {:cancel, :no_match_type}

      {:error, :mismatched_age} ->
        dispatch_error_completion(attrs, %{reason: :mismatched_age})
        {:cancel, :mismatched_age}

      error ->
        Logger.warning("Failed to fetch Faraday enrichment", details: inspect(error))
        dispatch_error_completion(attrs, %{reason: elem(error, 1)})
        {:cancel, :unknown_error}
    end
  end

  defp normalize_event(event) do
    for {key, val} <- event, do: {String.to_atom(key), val}, into: %{}
  end

  defp confirm_match(body, trestle_age_range) do
    raw_age = Map.get(body, "fdy_attribute_fig_age")
    converted_age = convert_age(raw_age)

    with {:match_type, type} when not is_nil(type) <- {:match_type, Map.get(body, "match_type")},
         {:faraday_age, faraday_age} when not is_nil(faraday_age) <-
           {:faraday_age, converted_age},
         {:trestle_age, trestle_age_range} when not is_nil(trestle_age_range) <-
           {:trestle_age, trestle_age_range},
         {:age_range, {min_age, max_age}} <- {:age_range, parse_age_range(trestle_age_range)},
         {:match?, true} <- {:match?, age_within_tolerance?(faraday_age, min_age, max_age)} do
      :ok
    else
      {:match_type, nil} ->
        {:error, :no_match_type}

      {:faraday_age, nil} ->
        :ok

      {:trestle_age, nil} ->
        :ok

      {:age_range, :error} ->
        :ok

      {:match?, false} ->
        log_age_mismatch(raw_age, trestle_age_range)
        {:error, :mismatched_age}
    end
  end

  defp reduce_response({key, val}, acc) do
    if field = @http_key_mapping[key] do
      converted_val = if field == :age, do: convert_age(val), else: val
      Map.put(acc, field, converted_val)
    else
      acc
    end
  end

  defp parse_age_range(age_range) when is_binary(age_range) do
    with [min_str, max_str] <- String.split(age_range, "-"),
         {min_age, ""} <- Integer.parse(min_str),
         {max_age, ""} <- Integer.parse(max_str) do
      {min_age, max_age}
    else
      _ -> :error
    end
  end

  defp parse_age_range(_), do: :error

  defp age_within_tolerance?(faraday_age, min_age, max_age) do
    faraday_age >= min_age - @age_range_tolerance and
      faraday_age <= max_age + @age_range_tolerance
  end

  defp log_age_mismatch(faraday_age, trestle_age_range) do
    Logger.warning(
      "Age mismatch in Faraday enrichment - faraday_age: #{faraday_age}, trestle_age_range: \"#{trestle_age_range}\""
    )
  end

  defp convert_age(age) when is_integer(age), do: age
  defp convert_age(age) when is_float(age), do: floor(age)

  defp convert_age(age) when is_binary(age) do
    case Float.parse(age) do
      {float_val, ""} -> floor(float_val)
      :error -> nil
    end
  end

  defp convert_age(_), do: nil

  # New structure helper functions
  defp make_identity_sets_new(attrs) do
    contact_data = normalize_contact_data(attrs.contact_data)

    case TenDigitPhone.cast(contact_data.phone) do
      {:ok, phone} ->
        email = List.first(contact_data.emails || [])
        id_sets = build_identity_sets(contact_data, phone, email)
        {:ok, id_sets}

      _error ->
        {:error, :invalid_phone_number}
    end
  end

  defp build_identity_sets(contact_data, phone, email) do
    Enum.map(contact_data.addresses || [], fn addr ->
      build_identity_set(addr, contact_data, phone, email)
    end)
  end

  defp build_identity_set(addr, contact_data, phone, email) do
    %{
      city: addr["city"] || addr[:city],
      email: email,
      house_number_and_street: build_street_address(addr),
      person_first_name: contact_data.first_name,
      person_last_name: contact_data.last_name,
      phone: phone,
      postcode: addr["zip"] || addr[:zip],
      state: addr["state"] || addr[:state]
    }
  end

  defp build_street_address(addr) do
    street_1 = addr["street_1"] || addr[:street_1]
    street_2 = addr["street_2"] || addr[:street_2] || ""
    String.trim("#{street_1} #{street_2}")
  end

  defp normalize_contact_data(contact_data) when is_map(contact_data) do
    # Handle both string and atom keys
    %{
      phone: contact_data["phone"] || contact_data[:phone],
      first_name: contact_data["first_name"] || contact_data[:first_name],
      last_name: contact_data["last_name"] || contact_data[:last_name],
      emails: contact_data["emails"] || contact_data[:emails] || [],
      addresses: contact_data["addresses"] || contact_data[:addresses] || [],
      trestle_age_range: contact_data["trestle_age_range"] || contact_data[:trestle_age_range]
    }
  end

  defp confirm_match_new(body, attrs) do
    contact_data = normalize_contact_data(attrs.contact_data)
    confirm_match(body, contact_data.trestle_age_range)
  end

  defp dispatch_completion(http_body, attrs) do
    contact_data = normalize_contact_data(attrs.contact_data)

    enrichment_data =
      http_body
      |> Enum.reduce(%{}, &reduce_response/2)
      |> Map.put(:phone, contact_data.phone)

    quality_metadata = %{
      match_type: Map.get(http_body, "match_type")
    }

    command = %CompleteProviderEnrichment{
      id: attrs.id,
      provider_type: "faraday",
      status: "success",
      enrichment_data: enrichment_data,
      quality_metadata: quality_metadata,
      timestamp: NaiveDateTime.truncate(NaiveDateTime.utc_now(), :second)
    }

    case CQRS.dispatch(command) do
      :ok ->
        age_validation = determine_age_validation_status(http_body, contact_data)

        Logger.info("Faraday enrichment completed",
          event_id: attrs.id,
          status: "success",
          match_type: Map.get(http_body, "match_type"),
          age_validation: age_validation,
          module: __MODULE__
        )

      {:error, error} ->
        Logger.warning("Faraday enrichment failed",
          event_id: attrs.id,
          status: "dispatch_error",
          error: inspect(error),
          module: __MODULE__
        )

        {:error, :dispatch}
    end
  end

  defp dispatch_error_completion(attrs, error_data) do
    command = %CompleteProviderEnrichment{
      id: attrs.id,
      provider_type: "faraday",
      status: "error",
      error_data: error_data,
      timestamp: NaiveDateTime.truncate(NaiveDateTime.utc_now(), :second)
    }

    case CQRS.dispatch(command) do
      :ok ->
        Logger.info("Faraday enrichment completed",
          event_id: attrs.id,
          status: "error",
          match_type: nil,
          age_validation: "skipped",
          module: __MODULE__
        )

      {:error, error} ->
        Logger.warning("Faraday enrichment failed",
          event_id: attrs.id,
          status: "dispatch_error",
          error: inspect(error),
          module: __MODULE__
        )

        {:error, :dispatch}
    end
  end

  defp determine_age_validation_status(http_body, contact_data) do
    raw_age = Map.get(http_body, "fdy_attribute_fig_age")
    converted_age = convert_age(raw_age)
    trestle_age_range = contact_data.trestle_age_range

    cond do
      is_nil(converted_age) ->
        "skipped_no_faraday_age"

      is_nil(trestle_age_range) ->
        "skipped_no_trestle_age"

      true ->
        validate_age_range(converted_age, trestle_age_range)
    end
  end

  defp validate_age_range(converted_age, trestle_age_range) do
    case parse_age_range(trestle_age_range) do
      {min_age, max_age} ->
        if age_within_tolerance?(converted_age, min_age, max_age), do: "passed", else: "failed"

      :error ->
        "skipped_invalid_range"
    end
  end
end
