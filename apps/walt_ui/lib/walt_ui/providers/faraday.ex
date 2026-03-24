defmodule WaltUi.Providers.Faraday do
  @moduledoc false

  use Repo.WaltSchema

  import Ecto.Changeset

  @type t :: %__MODULE__{}

  @required [:unified_contact_id]

  @optional ~w(
    address affluency age average_commute_time basement_area building_value city credit_rating
    date_empty_nester date_newly_married date_newly_single date_of_birth date_of_first_childbirth
    date_of_home_equity_loan date_of_income_change date_of_latest_mortgage date_retired education email
    first_name garage_spaces has_basement has_children_in_household has_pet has_pool home_equity_loan_amount
    homeowner_status household_income household_size interest_in_grandchildren is_active_on_social_media
    is_facebook_user is_instagram_user is_twitter_user last_name latest_mortgage_amount latest_mortgage_interest_rate
    latitude length_of_residence likes_travel liquid_resources living_area longitude lot_area lot_size_in_acres
    marital_status match_type mortgage_liability net_worth number_of_adults number_of_bathrooms number_of_bedrooms
    number_of_children occupation percent_equity phone postcode premover_rank probability_to_have_hot_tub
    propensity_percentile propensity_to_transact property_type state target_home_market_value vehicle_make
    vehicle_model vehicle_year wealth_resouces year_built zoning_type
  )a

  @derive {Jason.Encoder, only: @optional}
  schema "provider_faraday" do
    field :address, :string
    field :affluency, :boolean
    field :age, :integer
    field :average_commute_time, :integer
    field :basement_area, :integer
    field :building_value, :integer
    field :city, :string
    field :credit_rating, :integer
    field :date_empty_nester, :string
    field :date_newly_married, :string
    field :date_newly_single, :string
    field :date_of_birth, :string
    field :date_of_first_childbirth, :string
    field :date_of_home_equity_loan, :string
    field :date_of_income_change, :string
    field :date_of_latest_mortgage, :string
    field :date_retired, :string
    field :education, :string
    field :email, :string
    field :first_name, :string
    field :garage_spaces, :integer
    field :has_basement, :boolean
    field :has_children_in_household, :boolean
    field :has_pet, :boolean
    field :has_pool, :boolean
    field :home_equity_loan_amount, :integer
    field :homeowner_status, :string
    field :household_income, :integer
    field :household_size, :integer
    field :interest_in_grandchildren, :boolean
    field :is_active_on_social_media, :boolean
    field :is_facebook_user, :boolean
    field :is_instagram_user, :boolean
    field :is_twitter_user, :boolean
    field :last_name, :string
    field :latest_mortgage_amount, :integer
    field :latest_mortgage_interest_rate, :float
    field :latitude, :float
    field :length_of_residence, :integer
    field :likes_travel, :boolean
    field :liquid_resources, :string
    field :living_area, :integer
    field :longitude, :float
    field :lot_area, :integer
    field :lot_size_in_acres, :float
    field :marital_status, :string
    field :match_type, :string
    field :mortgage_liability, :integer
    field :net_worth, :integer
    field :number_of_adults, :integer
    field :number_of_bathrooms, :integer
    field :number_of_bedrooms, :integer
    field :number_of_children, :integer
    field :occupation, :string
    field :percent_equity, :integer
    field :phone, :string
    field :postcode, :string
    field :premover_rank, :integer
    field :probability_to_have_hot_tub, :integer
    field :propensity_percentile, :float
    field :propensity_to_transact, :float
    field :property_type, :string
    field :state, :string
    field :target_home_market_value, :integer
    field :vehicle_make, :string
    field :vehicle_model, :string
    field :vehicle_year, :integer
    field :wealth_resouces, :string
    field :year_built, :integer
    field :zoning_type, :string

    belongs_to :unified_contact, WaltUi.UnifiedRecords.Contact

    timestamps()
  end

  @spec changeset(t, map) :: Ecto.Changeset.t()
  def changeset(faraday \\ %__MODULE__{}, attrs) do
    faraday
    |> cast(attrs, @required ++ @optional)
    |> validate_required(@required)
  end

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

  @spec http_changeset(Ecto.Changeset.t(), map, map) :: Ecto.Changeset.t()
  def http_changeset(faraday, http, attrs \\ %{}) do
    http
    |> Enum.reduce(%{}, fn {key, val}, acc ->
      if field = @http_key_mapping[key], do: Map.put(acc, field, val), else: acc
    end)
    |> Map.merge(attrs)
    |> then(&changeset(faraday, &1))
  end
end
