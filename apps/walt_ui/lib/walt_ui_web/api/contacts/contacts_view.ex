defmodule WaltUiWeb.Api.ContactsView do
  use JSONAPI.View, type: "contacts", paginator: WaltUiWeb.Paginator

  import WaltUi.Guards

  alias WaltUi.Google.Gcs

  def fields do
    [
      :address,
      :avatar,
      :birthday,
      :budget_size,
      :contact_metadata,
      :date_of_home_purchase,
      :email,
      :emails,
      :events,
      :first_name,
      :last_name,
      :has_financing,
      :has_broker,
      :inserted_at,
      :is_favorite,
      :is_hidden,
      :is_highlighted,
      :latitude,
      :longitude,
      :phone,
      :phone_numbers,
      :ptt,
      :remote_id,
      :remote_source,
      :tags,
      :tier,
      :updated_at,
      :search
    ]
  end

  def address(%{street_1: nil}, _conn), do: nil

  def address(contact, _conn) do
    %{
      city: contact.city,
      state: contact.state,
      street_1: contact.street_1,
      street_2: contact.street_2,
      zip: contact.zip
    }
  end

  def avatar(contact, _conn) do
    Gcs.file_delivery_url(contact.avatar)
  end

  def events(%{events: %Ecto.Association.NotLoaded{}}, _conn), do: nil

  def events(%{events: events}, _conn) do
    Enum.map(events, fn event ->
      Map.take(event, [:type, :event, :inserted_at, :note_id])
    end)
  end

  # if no events field on the contact map
  def events(_contact, _conn), do: nil

  def contact_metadata(%{enrichment_id: nil}, _conn), do: nil
  def contact_metadata(%{enrichment: nil}, _conn), do: nil

  def contact_metadata(%{enrichment: data}, _conn) do
    %{
      main: %{
        full_name: data.full_name,
        date_of_birth: data.date_of_birth,
        age: data.age,
        education: data.education,
        marital_status: data.marital_status,
        date_newly_married: data.date_newly_married,
        date_newly_single: data.date_newly_single,
        occupation: data.occupation
      },
      financial: %{
        home_equity_loan_date: data.home_equity_loan_date,
        home_equity_loan_amount: data.home_equity_loan_amount,
        latest_mortgage_amount: data.latest_mortgage_amount,
        latest_mortgage_date: data.latest_mortgage_date,
        latest_mortgage_interest_rate: data.latest_mortgage_interest_rate,
        percent_equity: data.percent_equity,
        household_income: data.household_income,
        income_change_date: data.income_change_date,
        liquid_resources: data.liquid_resources,
        net_worth: data.net_worth,
        affluency: data.affluency,
        homeowner_status: data.homeowner_status,
        mortgage_liability: data.mortgage_liability,
        credit_rating: nil
      },
      home: %{
        lot_size_in_acres: data.lot_size_in_acres,
        probability_to_have_hot_tub: data.probability_to_have_hot_tub,
        target_home_market_value: data.target_home_market_value,
        property_type: data.property_type,
        number_of_bedrooms: data.number_of_bedrooms,
        number_of_bathrooms: data.number_of_bathrooms,
        year_built: data.year_built,
        length_of_residence: data.length_of_residence,
        average_commute_time: data.average_commute_time,
        has_basement: data.has_basement,
        basement_area: data.basement_area,
        homeowner_status: data.homeowner_status,
        garage_spaces: data.garage_spaces,
        living_area: data.living_area,
        lot_area: data.lot_area,
        has_pool: data.has_pool,
        zoning_type: data.zoning_type
      },
      personal_info: %{
        is_twitter_user: data.is_twitter_user,
        is_facebook_user: data.is_facebook_user,
        is_instagram_user: data.is_instagram_user,
        is_active_on_social_media: data.is_active_on_social_media,
        likes_travel: data.likes_travel,
        has_children_in_household: data.has_children_in_household,
        number_of_children: data.number_of_children,
        first_child_birthdate: data.first_child_birthdate,
        has_pet: data.has_pet,
        interest_in_grandchildren: data.interest_in_grandchildren,
        date_empty_nester: data.date_empty_nester,
        date_retired: data.date_retired,
        vehicle_make: data.vehicle_make,
        vehicle_model: data.vehicle_model,
        vehicle_year: data.vehicle_year
      }
    }
  end

  def has_financing(_contact, _conn), do: false

  # credo:disable-for-next-line Credo.Check.Readability.PredicateFunctionNames
  def is_highlighted(_contact, _conn), do: false

  # Unlock contact when:
  #  1. The user is a premium (paying) user
  #  2. The contact is unenriched
  #  3. The contact is enriched and showcased
  def tier(_contact, %{assigns: %{current_user: user}}) when is_premium_user(user), do: :premium
  def tier(%{enrichment: nil}, _conn), do: :premium
  def tier(%{is_showcased: true}, _conn), do: :premium
  def tier(_contact, _conn), do: :freemium

  def inserted_at(%{inserted_at: timestamp}, _conn) when is_binary(timestamp) do
    {:ok, ndt} = NaiveDateTime.from_iso8601(timestamp)
    DateTime.from_naive!(ndt, "Etc/UTC")
  end

  def inserted_at(%{inserted_at: %NaiveDateTime{}} = contact, _conn) do
    DateTime.from_naive!(contact.inserted_at, "Etc/UTC")
  end

  def inserted_at(_contact, _conn) do
    DateTime.utc_now()
  end

  def updated_at(%{updated_at: timestamp}, _conn) when is_binary(timestamp) do
    {:ok, ndt} = NaiveDateTime.from_iso8601(timestamp)
    DateTime.from_naive!(ndt, "Etc/UTC")
  end

  def updated_at(%{updated_at: %NaiveDateTime{}} = contact, _conn) do
    DateTime.from_naive!(contact.updated_at, "Etc/UTC")
  end

  def updated_at(_contact, _conn) do
    DateTime.utc_now()
  end

  def relationships do
    [notes: WaltUiWeb.Api.Contacts.NotesView]
  end
end
