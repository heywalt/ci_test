defmodule CQRS.Enrichments.Events.EnrichedWithFaraday do
  @moduledoc false

  use TypedStruct

  alias Repo.Types.TenDigitPhone

  @derive Jason.Encoder
  typedstruct do
    field :id, Ecto.UUID.t(), enforce: true
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
    field :phone, TenDigitPhone.t(), enforce: true
    field :postcode, :string
    field :premover_rank, :integer
    field :probability_to_have_hot_tub, :integer
    field :propensity_percentile, :float
    field :propensity_to_transact, :float
    field :property_type, :string
    field :state, :string
    field :target_home_market_value, :integer
    field :timestamp, NaiveDateTime.t(), enforce: true
    field :vehicle_make, :string
    field :vehicle_model, :string
    field :vehicle_year, :integer
    field :wealth_resources, :string
    field :year_built, :integer
    field :zoning_type, :string
  end
end
