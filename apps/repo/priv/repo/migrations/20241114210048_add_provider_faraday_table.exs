defmodule Repo.Migrations.AddProviderFaradayTable do
  use Ecto.Migration

  def change do
    create table(:provider_faraday, primary_key: false) do
      add :id, :uuid, primary_key: true

      add :address, :string
      add :affluency, :string
      add :age, :integer
      add :average_commute_time, :integer
      add :basement_area, :integer
      add :building_value, :integer
      add :city, :string
      add :credit_rating, :integer
      add :date_empty_nester, :string
      add :date_newly_married, :string
      add :date_newly_single, :string
      add :date_of_birth, :string
      add :date_of_first_childbirth, :string
      add :date_of_home_equity_loan, :string
      add :date_of_income_change, :string
      add :date_of_latest_mortgage, :string
      add :date_retired, :string
      add :education, :string
      add :email, :string
      add :first_name, :string
      add :garage_spaces, :integer
      add :has_basement, :boolean
      add :has_children_in_household, :boolean
      add :has_pet, :boolean
      add :has_pool, :boolean
      add :home_equity_loan_amount, :integer
      add :homeowner_status, :string
      add :household_income, :integer
      add :household_size, :integer
      add :interest_in_grandchildren, :string
      add :is_active_on_social_media, :boolean
      add :is_facebook_user, :boolean
      add :is_instagram_user, :boolean
      add :is_twitter_user, :boolean
      add :last_name, :string
      add :latest_mortgage_amount, :integer
      add :latest_mortgage_interest_rate, :string
      add :latitude, :float
      add :length_of_residence, :integer
      add :likes_travel, :boolean
      add :liquid_resources, :string
      add :living_area, :integer
      add :longitude, :float
      add :lot_area, :integer
      add :lot_size_in_acres, :float
      add :marital_status, :string
      add :match_type, :string
      add :mortgage_liability, :integer
      add :net_worth, :integer
      add :number_of_adults, :integer
      add :number_of_bathrooms, :integer
      add :number_of_bedrooms, :integer
      add :number_of_children, :integer
      add :occupation, :string
      add :percent_equity, :integer
      add :phone, :string
      add :postcode, :string
      add :premover_rank, :integer
      add :probability_to_have_hot_tub, :integer
      add :propensity_percentile, :float
      add :propensity_to_transact, :float
      add :property_type, :string
      add :state, :string
      add :target_home_market_value, :integer
      add :vehicle_make, :string
      add :vehicle_model, :string
      add :vehicle_year, :integer
      add :wealth_resouces, :string
      add :year_built, :integer
      add :zoning_type, :string

      add :unified_contact_id,
          references(:unified_contacts, type: :binary_id, on_delete: :delete_all)

      timestamps()
    end

    create index(:provider_faraday, :unified_contact_id)

    alter table(:unified_contacts) do
      add :faraday_id, references(:provider_faraday, type: :binary_id)
    end
  end
end
