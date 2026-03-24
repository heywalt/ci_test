defmodule Repo.Migrations.AddEnrichmentProjection do
  use Ecto.Migration

  def change do
    create table(:projection_enrichments) do
      add :full_name, :string
      add :first_name, :string
      add :last_name, :string
      add :date_of_birth, :string
      add :age, :string
      add :education, :string
      add :marital_status, :string
      add :date_newly_married, :string
      add :date_newly_single, :string
      add :occupation, :string
      add :home_equity_loan_date, :string
      add :home_equity_loan_amount, :string
      add :latest_mortgage_amount, :string
      add :latest_mortgage_date, :string
      add :latest_mortgage_interest_rate, :string
      add :percent_equity, :string
      add :household_income, :string
      add :income_change_date, :string
      add :liquid_resources, :string
      add :net_worth, :string
      add :affluency, :string
      add :homeowner_status, :string
      add :mortgage_liability, :string
      add :lot_size_in_acres, :string
      add :probability_to_have_hot_tub, :string
      add :target_home_market_value, :string
      add :property_type, :string
      add :number_of_bedrooms, :string
      add :number_of_bathrooms, :string
      add :year_built, :string
      add :length_of_residence, :string
      add :average_commute_time, :string
      add :has_basement, :boolean
      add :basement_area, :string
      add :garage_spaces, :string
      add :living_area, :string
      add :lot_area, :string
      add :has_pool, :boolean
      add :zoning_type, :string
      add :is_twitter_user, :boolean
      add :is_facebook_user, :boolean
      add :is_instagram_user, :boolean
      add :is_active_on_social_media, :boolean
      add :likes_travel, :boolean
      add :has_children_in_household, :boolean
      add :number_of_children, :string
      add :first_child_birthdate, :string
      add :has_pet, :boolean
      add :interest_in_grandchildren, :boolean
      add :date_empty_nester, :string
      add :date_retired, :string
      add :vehicle_make, :string
      add :vehicle_model, :string
      add :vehicle_year, :string

      timestamps()
    end
  end
end
