defmodule WaltUi.Admin.ContactMetadata do
  @moduledoc """
  Admin-specific contact metadata transformation and provider data access.

  This module handles enrichment data presentation for admin interfaces,
  providing both unified enrichment views and individual provider data access
  for debugging and analysis purposes.
  """

  alias WaltUi.Projections.Contact
  alias WaltUi.Projections.Endato
  alias WaltUi.Projections.Enrichment
  alias WaltUi.Projections.Faraday
  alias WaltUi.Projections.Gravatar
  alias WaltUi.Projections.Jitter
  alias WaltUi.Projections.Trestle

  @doc """
  Transforms contact enrichment data into structured metadata for admin display.

  Returns a tuple containing:
  - Structured metadata map with categories (main, financial, home, personal_info)
  - JSON-encoded string for raw display
  """
  @spec build_unified_metadata(Contact.t()) :: {map() | nil, String.t() | nil}
  def build_unified_metadata(%Contact{enrichment: nil}), do: {nil, nil}

  def build_unified_metadata(%Contact{enrichment: enrichment}) when is_nil(enrichment),
    do: {nil, nil}

  def build_unified_metadata(%Contact{enrichment: data}) do
    metadata = %{
      main: %{
        full_name: data.full_name,
        date_of_birth: data.date_of_birth,
        age: data.age,
        education: data.education,
        marital_status: data.marital_status,
        date_newly_married: data.date_newly_married,
        date_newly_single: data.date_newly_single,
        occupation: data.occupation
      },
      financial: %{
        home_equity_loan_date: data.home_equity_loan_date,
        home_equity_loan_amount: data.home_equity_loan_amount,
        latest_mortgage_amount: data.latest_mortgage_amount,
        latest_mortgage_date: data.latest_mortgage_date,
        latest_mortgage_interest_rate: data.latest_mortgage_interest_rate,
        percent_equity: data.percent_equity,
        household_income: data.household_income,
        income_change_date: data.income_change_date,
        liquid_resources: data.liquid_resources,
        net_worth: data.net_worth,
        affluency: data.affluency,
        homeowner_status: data.homeowner_status,
        mortgage_liability: data.mortgage_liability,
        credit_rating: nil
      },
      home: %{
        lot_size_in_acres: data.lot_size_in_acres,
        probability_to_have_hot_tub: data.probability_to_have_hot_tub,
        target_home_market_value: data.target_home_market_value,
        property_type: data.property_type,
        number_of_bedrooms: data.number_of_bedrooms,
        number_of_bathrooms: data.number_of_bathrooms,
        year_built: data.year_built,
        length_of_residence: data.length_of_residence,
        average_commute_time: data.average_commute_time,
        has_basement: data.has_basement,
        basement_area: data.basement_area,
        homeowner_status: data.homeowner_status,
        garage_spaces: data.garage_spaces,
        living_area: data.living_area,
        lot_area: data.lot_area,
        has_pool: data.has_pool,
        zoning_type: data.zoning_type
      },
      personal_info: %{
        is_twitter_user: data.is_twitter_user,
        is_facebook_user: data.is_facebook_user,
        is_instagram_user: data.is_instagram_user,
        is_active_on_social_media: data.is_active_on_social_media,
        likes_travel: data.likes_travel,
        has_children_in_household: data.has_children_in_household,
        number_of_children: data.number_of_children,
        first_child_birthdate: data.first_child_birthdate,
        has_pet: data.has_pet,
        interest_in_grandchildren: data.interest_in_grandchildren,
        date_empty_nester: data.date_empty_nester,
        date_retired: data.date_retired,
        vehicle_make: data.vehicle_make,
        vehicle_model: data.vehicle_model,
        vehicle_year: data.vehicle_year
      }
    }

    metadata_json = Jason.encode!(metadata, %{escape: :html_safe, pretty: true})
    {metadata, metadata_json}
  end

  def build_unified_metadata(_contact), do: {nil, nil}

  @doc """
  Fetches individual provider data for admin debugging purposes.

  Returns a map with provider data, including status information.
  """
  @spec fetch_provider_data(Contact.t()) :: %{
          endato: map() | nil,
          faraday: map() | nil,
          trestle: map() | nil,
          jitter: map() | nil,
          gravatar: map() | nil
        }

  def fetch_provider_data(%Contact{enrichment_id: enrichment_id}) do
    fetch_all_provider_data(enrichment_id)
  end

  def fetch_provider_data(_contact) do
    %{
      endato: nil,
      faraday: nil,
      trestle: nil,
      jitter: nil,
      gravatar: nil
    }
  end

  @doc """
  Fetches all provider data for a given enrichment ID in a single query.

  Returns a map with provider data for admin debugging.
  """
  @spec fetch_all_provider_data(binary() | nil) :: %{
          endato: Endato.t() | nil,
          faraday: Faraday.t() | nil,
          trestle: Trestle.t() | nil,
          jitter: Jitter.t() | nil,
          gravatar: Gravatar.t() | nil
        }
  def fetch_all_provider_data(nil) do
    %{
      endato: nil,
      faraday: nil,
      trestle: nil,
      jitter: nil,
      gravatar: nil
    }
  end

  def fetch_all_provider_data(enrichment_id) do
    import Ecto.Query

    query =
      from e in Enrichment,
        left_join: endato in Endato,
        on: endato.id == ^enrichment_id,
        left_join: faraday in Faraday,
        on: faraday.id == ^enrichment_id,
        left_join: trestle in Trestle,
        on: trestle.id == ^enrichment_id,
        left_join: jitter in Jitter,
        on: jitter.id == ^enrichment_id,
        left_join: gravatar in Gravatar,
        on: gravatar.id == ^enrichment_id,
        where: e.id == ^enrichment_id,
        select: %{
          endato: endato,
          faraday: faraday,
          trestle: trestle,
          jitter: jitter,
          gravatar: gravatar
        }

    Repo.one(query) || %{endato: nil, faraday: nil, trestle: nil, jitter: nil, gravatar: nil}
  end
end
