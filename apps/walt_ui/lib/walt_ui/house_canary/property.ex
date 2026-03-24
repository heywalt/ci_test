defmodule WaltUi.HouseCanary.Property do
  @moduledoc """
  Schema for HouseCanary property records.
  """
  use Repo.WaltSchema

  schema "properties" do
    # Property Identity & Location
    field :hc_address_id, :integer
    field :assessment_edition, :string
    field :hc_value_estimate, :integer
    field :address_slug, :string
    field :address, :string
    field :unit, :string
    field :city, :string
    field :state, :string
    field :zipcode, :string
    field :zipcode_plus4, :string
    field :latitude, :float
    field :longitude, :float
    field :county, :string
    field :address_street_number, :string
    field :address_street_name, :string
    field :address_street_type, :string

    # Owner Info
    field :owner_occupied_yn, :string
    field :owner_name, :string
    field :owner_vesting_type, :string
    field :owner_address, :string
    field :owner_unit_type, :string
    field :owner_unit_number, :string
    field :owner_city, :string
    field :owner_state, :string
    field :owner_zip, :string
    field :owner_zip_plus4, :string

    # Property Details
    field :year_built, :integer
    field :living_area, :float
    field :bedrooms, :integer
    field :bathrooms_total, :integer
    field :lot_size, :float

    # Last Sale
    field :last_close_date, :date
    field :last_close_price, :integer
    field :last_close_buyer1, :string
    field :last_close_buyer2, :string
    field :last_close_seller1, :string
    field :last_close_seller2, :string

    # Deed
    field :deed_date, :date
    field :deed_price, :string
    field :deed_type, :string
    field :deed_transfer_yn, :string

    # Lien 1
    field :lien1_borrower1_name, :string
    field :lien1_borrower1_first_name, :string
    field :lien1_borrower1_last_name, :string
    field :lien1_borrower2_name, :string
    field :lien1_borrower2_first_name, :string
    field :lien1_borrower2_last_name, :string
    field :lien1_lender_name, :string
    field :lien1_lender_type, :string
    field :lien1_loan_term, :integer
    field :lien1_loan_type, :string

    # Lien 2
    field :lien2_borrower1_name, :string
    field :lien2_borrower1_first_name, :string
    field :lien2_borrower1_last_name, :string
    field :lien2_borrower2_name, :string
    field :lien2_borrower2_first_name, :string
    field :lien2_borrower2_last_name, :string
    field :lien2_lender_name, :string
    field :lien2_lender_type, :string

    timestamps(type: :utc_datetime)
  end
end
