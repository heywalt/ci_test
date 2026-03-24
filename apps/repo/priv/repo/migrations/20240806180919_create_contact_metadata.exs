defmodule Repo.Migrations.CreateContactMetadata do
  use Ecto.Migration

  def change do
    create table(:contact_metadata, primary_key: false) do
      add :id, :uuid, primary_key: true, default: fragment("gen_random_uuid()"), null: false

      add :contact_id, references(:contacts, type: :binary_id, on_delete: :delete_all),
        null: false

      add :address, :string
      add :affluency, :string
      add :age, :string
      add :average_commute_time, :string
      add :basement_area, :string
      add :building_value, :string
      add :children_in_household, :string
      add :city, :string
      add :credit_rating, :string
      add :date_empty_nester, :string
      add :date_newly_married, :string
      add :date_newly_single, :string
      add :date_of_birth, :string
      add :date_retired, :string
      add :education, :string
      add :first_child_birthdate, :string
      add :first_name, :string
      add :garage_spaces, :string
      add :generation, :string
      add :has_basement, :string
      add :has_pet, :string
      add :has_pets_all, :string
      add :has_pool, :string
      add :homeowner_status, :string
      add :household_income, :string
      add :household_size, :string
      add :income_change_date, :string
      add :last_name, :string
      add :latest_mortgage_amount, :string
      add :latest_mortgage_date, :string
      add :latest_mortgage_interest_rate, :string
      add :latitude, :string
      add :length_of_residence, :string
      add :likes_travel, :string
      add :liquid_resources, :string
      add :living_area, :string
      add :longitude, :string
      add :lot_area, :string
      add :marital_status, :string
      add :match_type, :string
      add :mortgage_liability, :string
      add :net_worth, :string
      add :number_of_adults, :string
      add :number_of_bathrooms, :string
      add :number_of_bedrooms, :string
      add :number_of_children, :string
      add :number_of_grandchildren, :string
      add :occupation, :string
      add :percent_equity, :string
      add :phone, :string
      add :postcode, :string
      add :premover_rank, :string
      add :propensity_percentile, :string
      add :propensity_probability, :string
      add :property_type, :string
      add :state, :string
      add :vehicle_make, :string
      add :vehicle_model, :string
      add :vehicle_year, :string
      add :wealth_resources, :string
      add :year_built, :string
      add :zoning_type, :string

      timestamps()
    end
  end
end
