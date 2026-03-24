defmodule WaltUi.Projections.Enrichment do
  @moduledoc false

  use Repo.WaltSchema

  import Ecto.Changeset

  @type t :: %__MODULE__{}

  @required [:id]
  @optional ~w(full_name first_name last_name date_of_birth age education marital_status
    date_newly_married date_newly_single occupation home_equity_loan_date home_equity_loan_amount
    latest_mortgage_amount latest_mortgage_date latest_mortgage_interest_rate
    percent_equity household_income income_change_date liquid_resources net_worth
    affluency homeowner_status mortgage_liability lot_size_in_acres
    probability_to_have_hot_tub target_home_market_value property_type
    number_of_bedrooms number_of_bathrooms year_built length_of_residence
    average_commute_time has_basement basement_area garage_spaces
    living_area lot_area has_pool zoning_type is_twitter_user is_facebook_user
    is_instagram_user is_active_on_social_media likes_travel has_children_in_household
    number_of_children first_child_birthdate has_pet interest_in_grandchildren
    date_empty_nester date_retired vehicle_make vehicle_model vehicle_year
  )a

  @derive Jason.Encoder
  @primary_key {:id, Ecto.UUID, autogenerate: false}
  schema "projection_enrichments" do
    field :full_name, :string
    field :first_name, :string
    field :last_name, :string
    field :date_of_birth, :string
    field :age, :string
    field :education, :string
    field :marital_status, :string
    field :date_newly_married, :string
    field :date_newly_single, :string
    field :occupation, :string
    field :home_equity_loan_date, :string
    field :home_equity_loan_amount, :string
    field :latest_mortgage_amount, :string
    field :latest_mortgage_date, :string
    field :latest_mortgage_interest_rate, :string
    field :percent_equity, :string
    field :household_income, :string
    field :income_change_date, :string
    field :liquid_resources, :string
    field :net_worth, :string
    field :affluency, :string
    field :homeowner_status, :string
    field :mortgage_liability, :string
    field :lot_size_in_acres, :string
    field :probability_to_have_hot_tub, :string
    field :target_home_market_value, :string
    field :property_type, :string
    field :number_of_bedrooms, :string
    field :number_of_bathrooms, :string
    field :year_built, :string
    field :length_of_residence, :string
    field :average_commute_time, :string
    field :has_basement, :boolean
    field :basement_area, :string
    field :garage_spaces, :string
    field :living_area, :string
    field :lot_area, :string
    field :has_pool, :boolean
    field :zoning_type, :string
    field :is_twitter_user, :boolean
    field :is_facebook_user, :boolean
    field :is_instagram_user, :boolean
    field :is_active_on_social_media, :boolean
    field :likes_travel, :boolean
    field :has_children_in_household, :boolean
    field :number_of_children, :string
    field :first_child_birthdate, :string
    field :has_pet, :boolean
    field :interest_in_grandchildren, :boolean
    field :date_empty_nester, :string
    field :date_retired, :string
    field :vehicle_make, :string
    field :vehicle_model, :string
    field :vehicle_year, :string

    timestamps()
  end

  def changeset(enrichment \\ %__MODULE__{}, attrs) do
    enrichment
    |> cast(attrs, @required ++ @optional)
    |> validate_required(@required)
  end
end
