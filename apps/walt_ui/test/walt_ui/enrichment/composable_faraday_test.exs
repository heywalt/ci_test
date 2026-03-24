defmodule WaltUi.Enrichment.ComposableFaradayTest do
  use ExUnit.Case, async: true

  alias CQRS.Enrichments.Data.ProviderData
  alias WaltUi.Enrichment.Composable

  describe "normalize_data/1" do
    test "transforms address fields to standard format" do
      provider_data = %ProviderData{
        provider_type: "faraday",
        status: "success",
        enrichment_data: %{
          age: 35,
          city: "CHICAGO",
          state: "IL",
          address: "123 MAIN ST",
          postcode: "60601",
          household_income: 95_000,
          education: "Bachelor's Degree",
          marital_status: "Married",
          has_pet: true,
          ptt: 85
        },
        quality_metadata: %{match_type: "address_full_name"},
        received_at: NaiveDateTime.utc_now()
      }

      normalized = Composable.normalize_data(provider_data)

      # Address fields should be transformed: address -> street_1, postcode -> zip
      assert normalized.age == 35
      assert normalized.city == "CHICAGO"
      assert normalized.state == "IL"
      assert normalized.street_1 == "123 MAIN ST"
      assert normalized.zip == "60601"
      assert normalized.household_income == 95_000
      assert normalized.education == "Bachelor's Degree"
      assert normalized.marital_status == "Married"
      assert normalized.has_pet == true
      assert normalized.ptt == 85

      # Original keys should be removed
      refute Map.has_key?(normalized, :address)
      refute Map.has_key?(normalized, :postcode)
    end

    test "handles missing address fields gracefully" do
      provider_data = %ProviderData{
        provider_type: "faraday",
        status: "success",
        enrichment_data: %{
          age: 35,
          household_income: 75_000
          # No address fields
        },
        quality_metadata: %{match_type: "phone_only"},
        received_at: NaiveDateTime.utc_now()
      }

      normalized = Composable.normalize_data(provider_data)

      assert normalized.age == 35
      assert normalized.household_income == 75_000
      refute Map.has_key?(normalized, :city)
      refute Map.has_key?(normalized, :state)
      refute Map.has_key?(normalized, :street_1)
      refute Map.has_key?(normalized, :zip)
    end

    test "handles boolean false values correctly" do
      provider_data = %ProviderData{
        provider_type: "faraday",
        status: "success",
        enrichment_data: %{
          has_pet: false,
          likes_travel: false,
          has_children_in_household: false
        },
        quality_metadata: %{match_type: "email_full_name"},
        received_at: NaiveDateTime.utc_now()
      }

      normalized = Composable.normalize_data(provider_data)

      assert normalized.has_pet == false
      assert normalized.likes_travel == false
      assert normalized.has_children_in_household == false
    end
  end

  describe "calculate_quality_score/1" do
    test "returns score 90 for address_full_name match" do
      provider_data = %ProviderData{
        provider_type: "faraday",
        status: "success",
        enrichment_data: %{age: 35},
        quality_metadata: %{match_type: "address_full_name"},
        received_at: NaiveDateTime.utc_now()
      }

      score = Composable.calculate_quality_score(provider_data)

      assert score == 90
    end

    test "returns score 80 for phone_full_name match" do
      provider_data = %ProviderData{
        provider_type: "faraday",
        status: "success",
        enrichment_data: %{age: 35},
        quality_metadata: %{match_type: "phone_full_name"},
        received_at: NaiveDateTime.utc_now()
      }

      score = Composable.calculate_quality_score(provider_data)

      assert score == 80
    end

    test "returns score 70 for email_full_name match" do
      provider_data = %ProviderData{
        provider_type: "faraday",
        status: "success",
        enrichment_data: %{age: 35},
        quality_metadata: %{match_type: "email_full_name"},
        received_at: NaiveDateTime.utc_now()
      }

      score = Composable.calculate_quality_score(provider_data)

      assert score == 70
    end

    test "returns score 50 for address_last_name match" do
      provider_data = %ProviderData{
        provider_type: "faraday",
        status: "success",
        enrichment_data: %{age: 35},
        quality_metadata: %{match_type: "address_last_name"},
        received_at: NaiveDateTime.utc_now()
      }

      score = Composable.calculate_quality_score(provider_data)

      assert score == 50
    end

    test "returns score 45 for phone_last_name match" do
      provider_data = %ProviderData{
        provider_type: "faraday",
        status: "success",
        enrichment_data: %{age: 35},
        quality_metadata: %{match_type: "phone_last_name"},
        received_at: NaiveDateTime.utc_now()
      }

      score = Composable.calculate_quality_score(provider_data)

      assert score == 45
    end

    test "returns score 35 for email_last_name match" do
      provider_data = %ProviderData{
        provider_type: "faraday",
        status: "success",
        enrichment_data: %{age: 35},
        quality_metadata: %{match_type: "email_last_name"},
        received_at: NaiveDateTime.utc_now()
      }

      score = Composable.calculate_quality_score(provider_data)

      assert score == 35
    end

    test "returns score 20 for address_only match" do
      provider_data = %ProviderData{
        provider_type: "faraday",
        status: "success",
        enrichment_data: %{age: 35},
        quality_metadata: %{match_type: "address_only"},
        received_at: NaiveDateTime.utc_now()
      }

      score = Composable.calculate_quality_score(provider_data)

      assert score == 20
    end

    test "returns score 10 for email_only match" do
      provider_data = %ProviderData{
        provider_type: "faraday",
        status: "success",
        enrichment_data: %{age: 35},
        quality_metadata: %{match_type: "email_only"},
        received_at: NaiveDateTime.utc_now()
      }

      score = Composable.calculate_quality_score(provider_data)

      assert score == 10
    end

    test "returns score 20 for unknown match_type" do
      provider_data = %ProviderData{
        provider_type: "faraday",
        status: "success",
        enrichment_data: %{age: 35},
        quality_metadata: %{match_type: "unknown_type"},
        received_at: NaiveDateTime.utc_now()
      }

      score = Composable.calculate_quality_score(provider_data)

      assert score == 20
    end

    test "returns score 0 for nil match_type" do
      provider_data = %ProviderData{
        provider_type: "faraday",
        status: "success",
        enrichment_data: %{age: 35},
        quality_metadata: %{match_type: nil},
        received_at: NaiveDateTime.utc_now()
      }

      score = Composable.calculate_quality_score(provider_data)

      assert score == 0
    end

    test "returns score 0 for missing match_type key" do
      provider_data = %ProviderData{
        provider_type: "faraday",
        status: "success",
        enrichment_data: %{age: 35},
        quality_metadata: %{},
        received_at: NaiveDateTime.utc_now()
      }

      score = Composable.calculate_quality_score(provider_data)

      assert score == 0
    end
  end

  describe "extract_field/2" do
    test "extracts field from normalized data" do
      provider_data = %ProviderData{
        provider_type: "faraday",
        status: "success",
        enrichment_data: %{
          age: 35,
          city: "CHICAGO",
          household_income: 95_000,
          has_pet: true,
          likes_travel: false
        },
        quality_metadata: %{match_type: "address_full_name"},
        received_at: NaiveDateTime.utc_now()
      }

      assert Composable.extract_field(provider_data, :age) == 35
      assert Composable.extract_field(provider_data, :city) == "CHICAGO"
      assert Composable.extract_field(provider_data, :household_income) == 95_000
      assert Composable.extract_field(provider_data, :has_pet) == true
      assert Composable.extract_field(provider_data, :likes_travel) == false
    end

    test "returns nil for missing fields" do
      provider_data = %ProviderData{
        provider_type: "faraday",
        status: "success",
        enrichment_data: %{age: 35},
        quality_metadata: %{match_type: "address_full_name"},
        received_at: NaiveDateTime.utc_now()
      }

      assert Composable.extract_field(provider_data, :missing_field) == nil
      assert Composable.extract_field(provider_data, :city) == nil
      assert Composable.extract_field(provider_data, :household_income) == nil
    end
  end

  describe "get_field_capabilities/1" do
    test "returns fields that Faraday excels at" do
      provider_data = %ProviderData{
        provider_type: "faraday",
        status: "success",
        enrichment_data: %{},
        quality_metadata: %{},
        received_at: NaiveDateTime.utc_now()
      }

      capabilities = Composable.get_field_capabilities(provider_data)

      # Faraday's strengths: demographic, lifestyle, property, and Move Score data
      assert :age in capabilities
      assert :household_income in capabilities
      assert :education in capabilities
      assert :occupation in capabilities
      assert :marital_status in capabilities
      assert :has_pet in capabilities
      assert :likes_travel in capabilities
      assert :has_children_in_household in capabilities
      assert :is_active_on_social_media in capabilities
      assert :property_type in capabilities
      assert :number_of_bedrooms in capabilities
      assert :number_of_bathrooms in capabilities
      assert :garage_spaces in capabilities
      assert :ptt in capabilities

      # Faraday can provide names/addresses but they're not its specialty
      assert :first_name in capabilities
      assert :last_name in capabilities
      assert :city in capabilities
      assert :state in capabilities
      assert :street_1 in capabilities
      assert :zip in capabilities

      # Faraday doesn't typically provide email as a strength
      refute :email in capabilities
    end
  end
end
