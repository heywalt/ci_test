defmodule CQRS.Enrichments.Commands.EnrichWithFaraday do
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

  defimpl CQRS.Certifiable do
    import Ecto.Changeset
    alias CQRS.Middleware.CommandValidation.ValidatePhone

    def certify(cmd) do
      types = %{
        id: :binary_id,
        address: :string,
        affluency: :boolean,
        age: :integer,
        average_commute_time: :integer,
        basement_area: :integer,
        building_value: :integer,
        city: :string,
        credit_rating: :integer,
        date_empty_nester: :string,
        date_newly_married: :string,
        date_newly_single: :string,
        date_of_birth: :string,
        date_of_first_childbirth: :string,
        date_of_home_equity_loan: :string,
        date_of_income_change: :string,
        date_of_latest_mortgage: :string,
        date_retired: :string,
        education: :string,
        email: :string,
        first_name: :string,
        garage_spaces: :integer,
        has_basement: :boolean,
        has_children_in_household: :boolean,
        has_pet: :boolean,
        has_pool: :boolean,
        home_equity_loan_amount: :integer,
        homeowner_status: :string,
        household_income: :integer,
        household_size: :integer,
        interest_in_grandchildren: :boolean,
        is_active_on_social_media: :boolean,
        is_facebook_user: :boolean,
        is_instagram_user: :boolean,
        is_twitter_user: :boolean,
        last_name: :string,
        latest_mortgage_amount: :integer,
        latest_mortgage_interest_rate: :float,
        latitude: :float,
        length_of_residence: :integer,
        likes_travel: :boolean,
        liquid_resources: :string,
        living_area: :integer,
        longitude: :float,
        lot_area: :integer,
        lot_size_in_acres: :float,
        marital_status: :string,
        match_type: :string,
        mortgage_liability: :integer,
        net_worth: :integer,
        number_of_adults: :integer,
        number_of_bathrooms: :integer,
        number_of_bedrooms: :integer,
        number_of_children: :integer,
        occupation: :string,
        percent_equity: :integer,
        phone: :string,
        postcode: :string,
        premover_rank: :integer,
        probability_to_have_hot_tub: :integer,
        propensity_percentile: :float,
        propensity_to_transact: :float,
        property_type: :string,
        state: :string,
        target_home_market_value: :integer,
        timestamp: :naive_datetime,
        vehicle_make: :string,
        vehicle_model: :string,
        vehicle_year: :integer,
        wealth_resources: :string,
        year_built: :integer,
        zoning_type: :string
      }

      {struct(cmd.__struct__), types}
      |> cast(Map.from_struct(cmd), Map.keys(types))
      |> validate_required([:id, :phone, :timestamp])
      |> ValidatePhone.run()
      |> case do
        %{valid?: true} -> :ok
        changeset -> {:error, changeset.errors}
      end
    end
  end
end
