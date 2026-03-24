defmodule WaltUi.Enrichment.ComposableTrestleTest do
  use ExUnit.Case, async: true

  alias CQRS.Enrichments.Data.ProviderData
  alias WaltUi.Enrichment.Composable

  describe "normalize_data/1" do
    test "extracts address fields from first address in addresses list" do
      provider_data = %ProviderData{
        provider_type: "trestle",
        status: "success",
        enrichment_data: %{
          first_name: "John",
          last_name: "Smith",
          age_range: "35-44",
          addresses: [
            %{city: "Columbus", state: "OH", street_1: "123 Main St", zip: "43215"},
            %{city: "Dublin", state: "OH", street_1: "456 Oak Ave", zip: "43017"}
          ],
          emails: ["john@example.com", "jsmith@gmail.com"]
        },
        quality_metadata: %{match_count: 2, name_hint: "John Smith"},
        received_at: NaiveDateTime.utc_now()
      }

      normalized = Composable.normalize_data(provider_data)

      # Basic fields should be preserved
      assert normalized.first_name == "John"
      assert normalized.last_name == "Smith"

      # First email should be selected from emails list
      assert normalized.email == "john@example.com"

      # age_range should be mapped to age
      assert normalized.age == "35-44"
      refute Map.has_key?(normalized, :age_range)

      # First address should be flattened to top level
      assert normalized.city == "Columbus"
      assert normalized.state == "OH"
      assert normalized.street_1 == "123 Main St"
      assert normalized.zip == "43215"

      # addresses and emails lists should not be in normalized data
      refute Map.has_key?(normalized, :addresses)
      refute Map.has_key?(normalized, :emails)
    end

    test "handles empty addresses list gracefully" do
      provider_data = %ProviderData{
        provider_type: "trestle",
        status: "success",
        enrichment_data: %{
          first_name: "John",
          last_name: "Smith",
          addresses: [],
          emails: ["john@example.com"]
        },
        quality_metadata: %{match_count: 1, name_hint: "John Smith"},
        received_at: NaiveDateTime.utc_now()
      }

      normalized = Composable.normalize_data(provider_data)

      assert normalized.first_name == "John"
      assert normalized.last_name == "Smith"
      assert normalized.email == "john@example.com"
      refute Map.has_key?(normalized, :city)
      refute Map.has_key?(normalized, :state)
      refute Map.has_key?(normalized, :street_1)
      refute Map.has_key?(normalized, :zip)
    end

    test "handles empty emails list gracefully" do
      provider_data = %ProviderData{
        provider_type: "trestle",
        status: "success",
        enrichment_data: %{
          first_name: "John",
          emails: []
        },
        quality_metadata: %{match_count: 1, name_hint: "John Smith"},
        received_at: NaiveDateTime.utc_now()
      }

      normalized = Composable.normalize_data(provider_data)

      assert normalized.first_name == "John"
      refute Map.has_key?(normalized, :email)
    end
  end

  describe "calculate_quality_score/1" do
    test "returns highest score (95) for single match with exact name hint match" do
      provider_data = %ProviderData{
        provider_type: "trestle",
        status: "success",
        enrichment_data: %{
          first_name: "John",
          last_name: "Smith"
        },
        quality_metadata: %{match_count: 1, name_hint: "John Smith"},
        received_at: NaiveDateTime.utc_now()
      }

      score = Composable.calculate_quality_score(provider_data)

      assert score == 95
    end

    test "returns very high score (90) for multiple matches with exact name hint match" do
      provider_data = %ProviderData{
        provider_type: "trestle",
        status: "success",
        enrichment_data: %{
          first_name: "John",
          last_name: "Smith"
        },
        quality_metadata: %{match_count: 3, name_hint: "John Smith"},
        received_at: NaiveDateTime.utc_now()
      }

      score = Composable.calculate_quality_score(provider_data)

      # only slightly lower than single match with exact name
      assert score == 90
    end

    test "returns high score (85) for single match with partial name hint match" do
      provider_data = %ProviderData{
        provider_type: "trestle",
        status: "success",
        enrichment_data: %{
          first_name: "John",
          last_name: "Smith"
        },
        # only first name matches
        quality_metadata: %{match_count: 1, name_hint: "John"},
        received_at: NaiveDateTime.utc_now()
      }

      score = Composable.calculate_quality_score(provider_data)

      assert score == 85
    end

    test "returns medium score (65) for multiple matches with partial name hint match" do
      provider_data = %ProviderData{
        provider_type: "trestle",
        status: "success",
        enrichment_data: %{
          first_name: "John",
          last_name: "Smith"
        },
        quality_metadata: %{match_count: 2, name_hint: "John"},
        received_at: NaiveDateTime.utc_now()
      }

      score = Composable.calculate_quality_score(provider_data)

      assert score == 65
    end

    test "returns very low score (20) for name hint mismatch" do
      provider_data = %ProviderData{
        provider_type: "trestle",
        status: "success",
        enrichment_data: %{
          first_name: "John",
          last_name: "Smith"
        },
        # completely different name
        quality_metadata: %{match_count: 1, name_hint: "Jane Doe"},
        received_at: NaiveDateTime.utc_now()
      }

      score = Composable.calculate_quality_score(provider_data)

      # name mismatch indicates wrong person
      assert score == 20
    end

    test "returns very low score (10) for no matches" do
      provider_data = %ProviderData{
        provider_type: "trestle",
        status: "success",
        enrichment_data: %{},
        quality_metadata: %{match_count: 0, name_hint: "John Smith"},
        received_at: NaiveDateTime.utc_now()
      }

      score = Composable.calculate_quality_score(provider_data)

      assert score == 10
    end

    test "returns default score (50) for missing quality metadata" do
      provider_data = %ProviderData{
        provider_type: "trestle",
        status: "success",
        enrichment_data: %{},
        quality_metadata: %{},
        received_at: NaiveDateTime.utc_now()
      }

      score = Composable.calculate_quality_score(provider_data)

      assert score == 50
    end
  end

  describe "extract_field/2" do
    test "extracts field from normalized data after normalization" do
      provider_data = %ProviderData{
        provider_type: "trestle",
        status: "success",
        enrichment_data: %{
          first_name: "John",
          age_range: "35-44",
          addresses: [%{city: "Columbus", state: "OH"}],
          emails: ["john@example.com", "backup@email.com"]
        },
        quality_metadata: %{match_count: 1, name_hint: "John Smith"},
        received_at: NaiveDateTime.utc_now()
      }

      # Should extract from normalized data (age_range -> age, addresses flattened, first email selected)
      assert Composable.extract_field(provider_data, :first_name) == "John"
      # age_range mapped to age
      assert Composable.extract_field(provider_data, :age) == "35-44"
      assert Composable.extract_field(provider_data, :city) == "Columbus"
      assert Composable.extract_field(provider_data, :state) == "OH"
      # first email
      assert Composable.extract_field(provider_data, :email) == "john@example.com"
    end

    test "returns nil for missing fields" do
      provider_data = %ProviderData{
        provider_type: "trestle",
        status: "success",
        enrichment_data: %{first_name: "John"},
        quality_metadata: %{match_count: 1, name_hint: "John Smith"},
        received_at: NaiveDateTime.utc_now()
      }

      assert Composable.extract_field(provider_data, :missing_field) == nil
      assert Composable.extract_field(provider_data, :city) == nil
      assert Composable.extract_field(provider_data, :age) == nil
      assert Composable.extract_field(provider_data, :email) == nil
    end
  end

  describe "get_field_capabilities/1" do
    test "returns fields that Trestle excels at" do
      provider_data = %ProviderData{
        provider_type: "trestle",
        status: "success",
        enrichment_data: %{},
        quality_metadata: %{},
        received_at: NaiveDateTime.utc_now()
      }

      capabilities = Composable.get_field_capabilities(provider_data)

      # Trestle's strengths: names, contact info, addresses
      assert :first_name in capabilities
      assert :last_name in capabilities
      assert :age in capabilities
      assert :email in capabilities
      assert :city in capabilities
      assert :state in capabilities
      assert :street_1 in capabilities
      assert :street_2 in capabilities
      assert :zip in capabilities

      # Trestle doesn't provide demographic/lifestyle data
      refute :household_income in capabilities
      refute :education in capabilities
      refute :occupation in capabilities
      refute :marital_status in capabilities
      refute :has_pet in capabilities
      refute :property_type in capabilities
      refute :ptt in capabilities
    end
  end
end
