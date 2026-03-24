defmodule WaltUi.Projections.Faraday do
  @moduledoc false

  use Repo.WaltSchema

  import Ecto.Changeset
  require Logger

  @type t :: %__MODULE__{}

  @required [:id, :phone]

  @optional ~w(
    address affluency age average_commute_time basement_area building_value city credit_rating
    date_empty_nester date_newly_married date_newly_single date_of_birth date_of_first_childbirth
    date_of_home_equity_loan date_of_income_change date_of_latest_mortgage date_retired education email
    first_name garage_spaces has_basement has_children_in_household has_pet has_pool home_equity_loan_amount
    homeowner_status household_income household_size interest_in_grandchildren is_active_on_social_media
    is_facebook_user is_instagram_user is_twitter_user last_name latest_mortgage_amount latest_mortgage_interest_rate
    latitude length_of_residence likes_travel liquid_resources living_area longitude lot_area lot_size_in_acres
    marital_status match_type mortgage_liability net_worth number_of_adults number_of_bathrooms number_of_bedrooms
    number_of_children occupation percent_equity postcode premover_rank probability_to_have_hot_tub
    propensity_percentile propensity_to_transact property_type state target_home_market_value vehicle_make
    vehicle_model vehicle_year wealth_resources year_built zoning_type quality_metadata
  )a

  @derive {Jason.Encoder, except: [:__meta__, :__struct__]}
  @primary_key {:id, Ecto.UUID, autogenerate: false}
  schema "projection_enrichments_faraday" do
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
    field :phone, Repo.Types.TenDigitPhone
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
    field :wealth_resources, :string
    field :year_built, :integer
    field :zoning_type, :string
    field :quality_metadata, :map

    timestamps()
  end

  def changeset(faraday \\ %__MODULE__{}, attrs) do
    # Preprocess integer fields to handle floats and invalid values
    safe_attrs =
      attrs
      |> Map.update(:age, nil, &safe_integer_cast/1)
      |> Map.update(:average_commute_time, nil, &safe_integer_cast/1)
      |> Map.update(:basement_area, nil, &safe_integer_cast/1)
      |> Map.update(:building_value, nil, &safe_integer_cast/1)
      |> Map.update(:credit_rating, nil, &safe_integer_cast/1)
      |> Map.update(:garage_spaces, nil, &safe_integer_cast/1)
      |> Map.update(:home_equity_loan_amount, nil, &safe_integer_cast/1)
      |> Map.update(:household_income, nil, &safe_integer_cast/1)
      |> Map.update(:household_size, nil, &safe_integer_cast/1)
      |> Map.update(:latest_mortgage_amount, nil, &safe_integer_cast/1)
      |> Map.update(:length_of_residence, nil, &safe_integer_cast/1)
      |> Map.update(:living_area, nil, &safe_integer_cast/1)
      |> Map.update(:lot_area, nil, &safe_integer_cast/1)
      |> Map.update(:mortgage_liability, nil, &safe_integer_cast/1)
      |> Map.update(:net_worth, nil, &safe_integer_cast/1)
      |> Map.update(:number_of_adults, nil, &safe_integer_cast/1)
      |> Map.update(:number_of_bathrooms, nil, &safe_integer_cast/1)
      |> Map.update(:number_of_bedrooms, nil, &safe_integer_cast/1)
      |> Map.update(:number_of_children, nil, &safe_integer_cast/1)
      |> Map.update(:percent_equity, nil, &safe_integer_cast/1)
      |> Map.update(:premover_rank, nil, &safe_integer_cast/1)
      |> Map.update(:probability_to_have_hot_tub, nil, &safe_integer_cast/1)
      |> Map.update(:target_home_market_value, nil, &safe_integer_cast/1)
      |> Map.update(:vehicle_year, nil, &safe_integer_cast/1)
      |> Map.update(:year_built, nil, &safe_integer_cast/1)
      |> Map.update(:homeowner_status, nil, &safe_string_cast/1)

    faraday
    |> cast(safe_attrs, @required ++ @optional)
    |> validate_required(@required)
  end

  defp safe_integer_cast(val) when is_integer(val), do: val
  defp safe_integer_cast(val) when is_float(val), do: trunc(val)
  defp safe_integer_cast(_), do: nil

  defp safe_string_cast(val) when is_binary(val), do: val

  defp safe_string_cast(0) do
    Logger.warning("Faraday returned 0 for homeowner_status, setting to nil")
    nil
  end

  defp safe_string_cast(val) when is_integer(val) do
    Logger.warning("Faraday returned unexpected integer for homeowner_status", value: val)
    nil
  end

  defp safe_string_cast(val) when val != nil do
    Logger.warning("Faraday returned unexpected homeowner_status value", value: val)
    nil
  end

  defp safe_string_cast(_), do: nil
end
