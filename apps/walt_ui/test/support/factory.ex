defmodule WaltUi.Factory do
  @moduledoc false

  use ExMachina.Ecto, repo: Repo

  alias Faker.Phone.EnUs, as: FakerPhoneEnUs

  def calendar_factory do
    %WaltUi.Calendars.Calendar{
      name: "My Main Calendar",
      source: :google,
      source_id: "my_main_calendar_google",
      timezone: "America/Denver",
      user: build(:user)
    }
  end

  def contact_factory do
    %WaltUi.Projections.Contact{
      avatar: Faker.Internet.image_url(),
      city: Faker.Address.city(),
      email: Faker.Internet.email(),
      first_name: Faker.Person.first_name(),
      id: Ecto.UUID.generate(),
      is_favorite: false,
      last_name: Faker.Person.last_name(),
      latitude: nil,
      longitude: nil,
      phone: Faker.Util.format("+1555%7d"),
      ptt: :rand.uniform(90),
      remote_id: Faker.Util.format("%4d%4b-%4d%4b"),
      remote_source: "mobile",
      state: Faker.Address.state_abbr(),
      street_1: Faker.Address.street_address(),
      street_2: nil,
      user_id: insert(:user, email: "contact_test_#{System.unique_integer()}@example.com").id,
      zip: Faker.Address.zip_code()
    }
  end

  def contact_event_factory do
    %WaltUi.Contacts.ContactEvent{event: "Test Event", type: "test"}
  end

  def contact_highlight_factory do
    %WaltUi.Contacts.Highlight{contact: build(:contact), user: build(:user)}
  end

  def contact_showcase_factory do
    %WaltUi.Projections.ContactShowcase{
      contact_id: Ecto.UUID.generate(),
      enrichment_type: :lesser,
      user_id: Ecto.UUID.generate()
    }
  end

  def contact_tag_factory do
    %WaltUi.ContactTags.ContactTag{
      contact_id: Ecto.UUID.generate(),
      tag: build(:tag),
      user: build(:user)
    }
  end

  def enrichment_factory do
    %WaltUi.Projections.Enrichment{
      id: Ecto.UUID.generate(),
      affluency: "true",
      home_equity_loan_amount: "$0-$50k",
      home_equity_loan_date: "9/10/2018",
      homeowner_status: "Probable Owner",
      household_income: "$70k+",
      income_change_date: "2/14/2010",
      latest_mortgage_amount: "$0-$50k",
      latest_mortgage_date: "7/5/2016",
      latest_mortgage_interest_rate: "3-4%",
      liquid_resources: "$25k - $49k",
      mortgage_liability: "$50k-$100k",
      net_worth: "$50k-$100k",
      percent_equity: "60%-70%",
      average_commute_time: "10-20",
      basement_area: "13326",
      garage_spaces: "0-2",
      has_basement: true,
      has_pool: true,
      length_of_residence: "15-20",
      living_area: "26296",
      lot_area: "1.86",
      lot_size_in_acres: "1-2",
      number_of_bathrooms: "3-4",
      number_of_bedrooms: "3-4",
      probability_to_have_hot_tub: "90%-100%",
      property_type: "APARTMENT",
      target_home_market_value: "$1M+",
      year_built: "1994",
      zoning_type: "RR",
      age: "65+",
      date_newly_married: "5/1/2011",
      date_newly_single: "8/17/2023",
      date_of_birth: "8/17/1958",
      education: "Completed College",
      full_name: "Peter Parker",
      marital_status: "Married",
      occupation: "Business Owner",
      date_empty_nester: "1/1/2008",
      date_retired: "2/13/2010",
      first_child_birthdate: "4/4/1991",
      has_children_in_household: false,
      has_pet: true,
      interest_in_grandchildren: false,
      is_active_on_social_media: true,
      is_facebook_user: true,
      is_instagram_user: false,
      is_twitter_user: true,
      likes_travel: false,
      number_of_children: "0-2",
      vehicle_make: "Ford",
      vehicle_model: "Focus",
      vehicle_year: "2004"
    }
  end

  def possible_address_factory do
    %WaltUi.Projections.PossibleAddress{
      id: Ecto.UUID.generate(),
      enrichment_id: Ecto.UUID.generate(),
      street_1: Faker.Address.street_address(),
      street_2: nil,
      city: Faker.Address.city(),
      state: Faker.Address.state_abbr(),
      zip: Faker.Address.zip_code()
    }
  end

  def provider_endato_factory do
    %WaltUi.Providers.Endato{
      city: "Circleville",
      email: "foo@example.com",
      first_name: "Wade",
      last_name: "Wilson",
      phone: "5551231234",
      state: "OH",
      street_1: "428 E Main St",
      zip: "43113"
    }
  end

  def provider_faraday_factory do
    %WaltUi.Providers.Faraday{
      address: "123 Main St #42",
      affluency: "true",
      age: 72,
      average_commute_time: 15,
      basement_area: 1238,
      building_value: 475_000,
      city: "Circleville",
      date_empty_nester: "2008-01-01",
      date_newly_married: "2011-05-01",
      date_newly_single: "2023-08-17",
      date_of_birth: "1958-08-17",
      date_of_first_childbirth: "1991-04-04",
      date_of_home_equity_loan: "2018-09-10",
      date_of_income_change: "2010-02-14",
      date_of_latest_mortgage: "2016-07-05",
      date_retired: "2010-02-13",
      education: "Completed College",
      first_name: "Peter",
      garage_spaces: 2,
      has_basement: true,
      has_children_in_household: false,
      has_pet: true,
      has_pool: true,
      home_equity_loan_amount: 25_000,
      homeowner_status: "Probable Owner",
      household_income: 75_000,
      household_size: 3,
      interest_in_grandchildren: false,
      is_active_on_social_media: true,
      is_facebook_user: true,
      is_instagram_user: false,
      is_twitter_user: true,
      last_name: "Parker",
      latest_mortgage_amount: 25_000,
      latest_mortgage_interest_rate: 3.5,
      latitude: "41.91811752",
      length_of_residence: 16,
      likes_travel: false,
      liquid_resources: "$2500 - $4999",
      living_area: 2443,
      longitude: "-87.7443924",
      lot_area: 7527,
      lot_size_in_acres: 1.5,
      marital_status: "Married",
      match_type: "address_full_name",
      mortgage_liability: 75_000,
      net_worth: 80_000,
      number_of_adults: 2,
      number_of_bathrooms: 3,
      number_of_bedrooms: 4,
      number_of_children: 2,
      occupation: "Business Owner",
      percent_equity: 61,
      phone: "5551231234",
      postcode: "43113",
      premover_rank: 45,
      probability_to_have_hot_tub: 99,
      propensity_percentile: "71",
      propensity_to_transact: 0.824256987601,
      property_type: "APARTMENT",
      state: "OH",
      target_home_market_value: 1_100_000,
      vehicle_make: "Ford",
      vehicle_model: "Focus",
      vehicle_year: "2004",
      wealth_resouces: "$250,000 - $499,999",
      year_built: 1994,
      zoning_type: "RR"
    }
  end

  def endato_factory do
    %WaltUi.Projections.Endato{
      emails: ["foo@example.com"],
      first_name: "Wade",
      id: Ecto.UUID.generate(),
      last_name: "Wilson",
      phone: "5551231234",
      addresses: [
        %WaltUi.Projections.Endato.Address{
          street_1: "428 E Main St",
          street_2: nil,
          city: "Circleville",
          state: "OH",
          zip: "43113"
        }
      ]
    }
  end

  def external_account_factory do
    %WaltUi.ExternalAccounts.ExternalAccount{
      provider: "google",
      provider_user_id: "110718714913944881341",
      access_token:
        "ya29.a0AXeO80SldbSEx-1xcXDcKBm-rr-DkCchDTHj5MXMekZ-romdHvpDyjSzqw4-YSOwL7jYxJvN6ji5KUYPX-jAZL2hHI7GC3B-ZvqgPqdn1kYTaJDNQ2tIbQiTfNqTfoSrhC2VKZXACaEiUy4tMM1Cv9w9MdxiZ6Skg-EEJyYMcAaCgYKAdoSARESFQHGX2MikiVJOQVeTZIe_406JXQBsA0177",
      refresh_token:
        "1//064_yYnc3Rv4TCgYIARAAGAYSNwF-L9IrEo-l_u4gYPCxr3g2HlCU-ZvhZP17I0NSJLaNyP8HNskQNAvPvblgvwuc-dnboqBLOVc",
      expires_at: DateTime.add(DateTime.utc_now(), 1, :hour),
      token_source: "web",
      user: build(:user)
    }
  end

  def faraday_factory do
    %WaltUi.Projections.Faraday{
      address: "123 Main St #42",
      affluency: "true",
      age: 72,
      average_commute_time: 15,
      basement_area: 1238,
      building_value: 475_000,
      city: "Circleville",
      date_empty_nester: "2008-01-01",
      date_newly_married: "2011-05-01",
      date_newly_single: "2023-08-17",
      date_of_birth: "1958-08-17",
      date_of_first_childbirth: "1991-04-04",
      date_of_home_equity_loan: "2018-09-10",
      date_of_income_change: "2010-02-14",
      date_of_latest_mortgage: "2016-07-05",
      date_retired: "2010-02-13",
      education: "Completed College",
      first_name: "Peter",
      garage_spaces: 2,
      has_basement: true,
      has_children_in_household: false,
      has_pet: true,
      has_pool: true,
      home_equity_loan_amount: 25_000,
      homeowner_status: "Probable Owner",
      household_income: 75_000,
      household_size: 3,
      id: Ecto.UUID.generate(),
      interest_in_grandchildren: false,
      is_active_on_social_media: true,
      is_facebook_user: true,
      is_instagram_user: false,
      is_twitter_user: true,
      last_name: "Parker",
      latest_mortgage_amount: 25_000,
      latest_mortgage_interest_rate: 3.5,
      latitude: "41.91811752",
      length_of_residence: 16,
      likes_travel: false,
      liquid_resources: "$2500 - $4999",
      living_area: 2443,
      longitude: "-87.7443924",
      lot_area: 7527,
      lot_size_in_acres: 1.5,
      marital_status: "Married",
      match_type: "address_full_name",
      mortgage_liability: 75_000,
      net_worth: 80_000,
      number_of_adults: 2,
      number_of_bathrooms: 3,
      number_of_bedrooms: 4,
      number_of_children: 2,
      occupation: "Business Owner",
      percent_equity: 61,
      phone: "5551231234",
      postcode: "43113",
      premover_rank: 45,
      probability_to_have_hot_tub: 99,
      propensity_percentile: "71",
      propensity_to_transact: 0.824256987601,
      property_type: "APARTMENT",
      state: "OH",
      target_home_market_value: 1_100_000,
      vehicle_make: "Ford",
      vehicle_model: "Focus",
      vehicle_year: "2004",
      wealth_resources: "$250,000 - $499,999",
      year_built: 1994,
      zoning_type: "RR"
    }
  end

  def fcm_token_factory do
    %WaltUi.Notifications.FcmToken{
      token: sequence(:fcm_token, &"fcm_token_#{&1}"),
      user_id: insert(:user).id
    }
  end

  def gravatar_factory do
    %WaltUi.Projections.Gravatar{
      id: Ecto.UUID.generate(),
      email: "foo@example.com",
      url: "https://gravatar.com/avatar/a27fee606501906b745105c230f1742c"
    }
  end

  def jitter_factory do
    %WaltUi.Projections.Jitter{
      id: Ecto.UUID.generate(),
      ptt: :rand.uniform(99)
    }
  end

  def note_factory do
    %WaltUi.Directory.Note{note: "Some note text", contact: build(:contact)}
  end

  def ptt_score_factory do
    %WaltUi.Projections.PttScore{
      contact_id: Ecto.UUID.generate(),
      occurred_at: NaiveDateTime.utc_now(),
      score: 42,
      score_type: :ptt
    }
  end

  def realtor_identity_factory do
    %WaltUi.Realtors.RealtorIdentity{
      email: sequence(:realtor_email, &"agent#{&1}@example.com")
    }
  end

  def realtor_brokerage_factory do
    %WaltUi.Realtors.RealtorBrokerage{
      name: sequence(:brokerage_name, &"Brokerage #{&1}")
    }
  end

  def realtor_address_factory do
    %WaltUi.Realtors.RealtorAddress{
      address_1: Faker.Address.street_address(),
      city: Faker.Address.city(),
      state: Faker.Address.state_abbr(),
      zip: Faker.Address.zip_code()
    }
  end

  def realtor_association_factory do
    %WaltUi.Realtors.RealtorAssociation{
      name: sequence(:association_name, &"Association of Realtors #{&1}")
    }
  end

  def realtor_record_factory do
    first_name = Faker.Person.first_name()
    last_name = Faker.Person.last_name()

    content_hash =
      [first_name, last_name, "", "", "", "", ""]
      |> Enum.join("|")
      |> then(&:crypto.hash(:sha256, &1))
      |> Base.encode16(case: :lower)

    %WaltUi.Realtors.RealtorRecord{
      first_name: first_name,
      last_name: last_name,
      content_hash: content_hash,
      identity: build(:realtor_identity)
    }
  end

  def realtor_phone_number_factory do
    %WaltUi.Realtors.RealtorPhoneNumber{
      number: sequence(:phone_number, &"555#{String.pad_leading(to_string(&1), 7, "0")}"),
      type: "cell"
    }
  end

  def realtor_record_phone_number_factory do
    %WaltUi.Realtors.RealtorRecordPhoneNumber{
      record: build(:realtor_record),
      phone_number: build(:realtor_phone_number)
    }
  end

  def subscription_factory do
    %WaltUi.Subscriptions.Subscription{
      expires_on: Date.utc_today(),
      store: :apple,
      user: build(:user)
    }
  end

  def tag_factory do
    %WaltUi.Tags.Tag{
      name: "Test Tag #{System.unique_integer()}",
      color: "#000000",
      user: build(:user)
    }
  end

  def trestle_factory do
    %WaltUi.Projections.Trestle{
      id: Ecto.UUID.generate(),
      age_range: "25-34",
      emails: ["foo@example.com"],
      first_name: "Wade",
      last_name: "Wilson",
      phone: "5551231234",
      addresses: [
        %WaltUi.Projections.Trestle.Address{
          street_1: "428 E Main St",
          street_2: nil,
          city: "Circleville",
          state: "OH",
          zip: "43113"
        }
      ]
    }
  end

  def task_factory do
    %WaltUi.Tasks.Task{
      contact: build(:contact),
      created_by: :system,
      description: "A task",
      due_at: NaiveDateTime.add(NaiveDateTime.utc_now(), 1, :day),
      user: build(:user)
    }
  end

  def unified_contact_factory do
    %WaltUi.UnifiedRecords.Contact{
      contacts: build_list(2, :contact),
      endato: build(:provider_endato),
      faraday: build(:provider_faraday),
      gravatar: build(:gravatar),
      phone: FakerPhoneEnUs.phone()
    }
  end

  def user_factory do
    %WaltUi.Account.User{
      auth_uid: sequence(:auth_uid, &"auth0bogusId#{&1}"),
      email: sequence(:email, &"some_user#{&1}@example.com"),
      first_name: "Some",
      last_name: "User",
      phone: "8015551111"
    }
  end
end
