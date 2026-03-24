defmodule HouseCanaryRepo.Migrations.CreateProperties do
  use Ecto.Migration

  def change do
    create table(:properties) do
      # Property Identity & Location
      add :hc_address_id, :integer
      add :assessment_edition, :string
      add :hc_value_estimate, :integer
      add :address_slug, :text
      add :address, :text
      add :unit, :string
      add :city, :string
      add :state, :string
      add :zipcode, :string
      add :zipcode_plus4, :string
      add :latitude, :float
      add :longitude, :float
      add :county, :string
      add :address_street_number, :string
      add :address_street_name, :string
      add :address_street_type, :string

      # Owner Info
      add :owner_occupied_yn, :string
      add :owner_name, :string
      add :owner_vesting_type, :string
      add :owner_address, :string
      add :owner_unit_type, :string
      add :owner_unit_number, :string
      add :owner_city, :string
      add :owner_state, :string
      add :owner_zip, :string
      add :owner_zip_plus4, :string

      # Property Details
      add :year_built, :integer
      add :living_area, :float
      add :bedrooms, :integer
      add :bathrooms_total, :integer
      add :lot_size, :float

      # Last Sale
      add :last_close_date, :date
      add :last_close_price, :integer
      add :last_close_buyer1, :text
      add :last_close_buyer2, :text
      add :last_close_seller1, :text
      add :last_close_seller2, :text

      # Deed
      add :deed_date, :date
      add :deed_price, :string
      add :deed_type, :string
      add :deed_transfer_yn, :string

      # Lien 1
      add :lien1_borrower1_name, :string
      add :lien1_borrower1_first_name, :string
      add :lien1_borrower1_last_name, :string
      add :lien1_borrower2_name, :string
      add :lien1_borrower2_first_name, :string
      add :lien1_borrower2_last_name, :string
      add :lien1_lender_name, :string
      add :lien1_lender_type, :string
      add :lien1_loan_term, :integer
      add :lien1_loan_type, :string

      # Lien 2
      add :lien2_borrower1_name, :string
      add :lien2_borrower1_first_name, :string
      add :lien2_borrower1_last_name, :string
      add :lien2_borrower2_name, :string
      add :lien2_borrower2_first_name, :string
      add :lien2_borrower2_last_name, :string
      add :lien2_lender_name, :string
      add :lien2_lender_type, :string

      timestamps(type: :utc_datetime)
    end

    create unique_index(:properties, [:hc_address_id])
    create index(:properties, [:address_street_number, :address_street_name, :city, :state, :zipcode],
      name: :properties_address_components_index
    )
    create index(:properties, [:zipcode])
    create index(:properties, [:owner_name])
    create index(:properties, [:lien1_borrower1_last_name])
    create index(:properties, [:lien2_borrower1_last_name])
  end
end
