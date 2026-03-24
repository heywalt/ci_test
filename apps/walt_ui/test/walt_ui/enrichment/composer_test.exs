defmodule WaltUi.Enrichment.ComposerTest do
  use ExUnit.Case, async: true

  alias CQRS.Enrichments.Data.ProviderData
  alias WaltUi.Enrichment.Composer

  describe "compose/2" do
    test "returns composed_data, data_sources, and provider_scores structure" do
      provider_data = [
        %ProviderData{
          provider_type: "faraday",
          status: "success",
          enrichment_data: %{age: 35, household_income: 75_000},
          quality_metadata: %{match_type: "address_full_name"},
          received_at: NaiveDateTime.utc_now()
        }
      ]

      result = Composer.compose(provider_data, :default, "test-enrichment-id")

      assert %{composed_data: _, data_sources: _, provider_scores: _} = result
      assert is_map(result.composed_data)
      assert is_map(result.data_sources)
      assert is_map(result.provider_scores)
    end

    test "handles empty provider_data list" do
      result = Composer.compose([], :default, "test-enrichment-id")

      assert result.composed_data == %{}
      assert result.data_sources == %{}
      assert result.provider_scores == %{}
    end

    test "calculates provider scores for successful providers" do
      provider_data = [
        %ProviderData{
          provider_type: "faraday",
          status: "success",
          enrichment_data: %{age: 35, household_income: 75_000},
          quality_metadata: %{match_type: "address_full_name"},
          received_at: NaiveDateTime.utc_now()
        },
        %ProviderData{
          provider_type: "trestle",
          status: "success",
          enrichment_data: %{first_name: "John", age_range: "35-44"},
          quality_metadata: %{match_count: 2, name_hint: "John"},
          received_at: NaiveDateTime.utc_now()
        }
      ]

      result = Composer.compose(provider_data, :default, "test-enrichment-id")

      assert Map.has_key?(result.provider_scores, "faraday")
      assert Map.has_key?(result.provider_scores, "trestle")
      assert is_integer(result.provider_scores["faraday"])
      assert is_integer(result.provider_scores["trestle"])
      assert result.provider_scores["faraday"] >= 0
      assert result.provider_scores["trestle"] >= 0
    end

    test "excludes error providers from provider_scores" do
      provider_data = [
        %ProviderData{
          provider_type: "faraday",
          status: "error",
          error_data: %{reason: "timeout"},
          received_at: NaiveDateTime.utc_now()
        },
        %ProviderData{
          provider_type: "trestle",
          status: "success",
          enrichment_data: %{first_name: "John", age_range: "35-44"},
          quality_metadata: %{match_count: 1, name_hint: nil},
          received_at: NaiveDateTime.utc_now()
        }
      ]

      result = Composer.compose(provider_data, :default, "test-enrichment-id")

      refute Map.has_key?(result.provider_scores, "faraday")
      assert Map.has_key?(result.provider_scores, "trestle")
    end

    test "handles unsupported provider types without crashing" do
      provider_data = [
        %ProviderData{
          provider_type: "endato",
          status: "success",
          enrichment_data: %{
            first_name: "Jane",
            last_name: "Doe",
            addresses: [%{street_1: "123 Main St", city: "Anytown", state: "CA", zip: "90210"}],
            emails: ["jane@example.com"]
          },
          quality_metadata: %{match_score: 85},
          received_at: NaiveDateTime.utc_now()
        },
        %ProviderData{
          provider_type: "unknown_provider",
          status: "success",
          enrichment_data: %{some_field: "some_value"},
          quality_metadata: %{},
          received_at: NaiveDateTime.utc_now()
        }
      ]

      # This should not crash with a FunctionClauseError
      result = Composer.compose(provider_data, :default, "test-enrichment-id")

      assert is_map(result.composed_data)
      assert is_map(result.data_sources)
      assert is_map(result.provider_scores)
    end

    test "skips providers with error status" do
      provider_data = [
        %ProviderData{
          provider_type: "faraday",
          status: "error",
          error_data: %{reason: "timeout"},
          received_at: NaiveDateTime.utc_now()
        },
        %ProviderData{
          provider_type: "trestle",
          status: "success",
          enrichment_data: %{first_name: "John", age_range: "35-44"},
          quality_metadata: %{match_count: 1, name_hint: nil},
          received_at: NaiveDateTime.utc_now()
        }
      ]

      result = Composer.compose(provider_data, :default, "test-enrichment-id")

      # Should only use Trestle data, ignore failed Faraday
      assert result.composed_data.first_name == "John"
      assert result.composed_data.age == "35-44"
      assert result.data_sources.first_name == "trestle"
      assert result.data_sources.age == "trestle"
    end
  end

  describe "ProviderAdapter protocol integration" do
    test "uses protocol for data normalization and quality scoring" do
      provider_data = [
        %ProviderData{
          provider_type: "trestle",
          status: "success",
          enrichment_data: %{
            first_name: "John",
            last_name: "Smith",
            age_range: "35-44",
            addresses: [%{city: "Columbus", state: "OH", street_1: "123 Main St", zip: "43215"}],
            emails: ["john@example.com", "backup@email.com"]
          },
          quality_metadata: %{match_count: 1, name_hint: "John Smith"},
          received_at: NaiveDateTime.utc_now()
        },
        %ProviderData{
          provider_type: "faraday",
          status: "success",
          enrichment_data: %{
            age: 35,
            city: "CHICAGO",
            state: "IL",
            household_income: 95_000,
            education: "Bachelor's Degree"
          },
          quality_metadata: %{match_type: "address_full_name"},
          received_at: NaiveDateTime.utc_now()
        }
      ]

      result = Composer.compose(provider_data, :default, "test-enrichment-id")

      # Should use protocol to normalize Trestle data (addresses -> flat fields, emails -> email)
      assert result.composed_data.first_name == "John"
      assert result.composed_data.last_name == "Smith"
      assert result.composed_data.email == "john@example.com"

      # Should use protocol for quality-based selection
      # Faraday has address_full_name (quality 90) vs Trestle (quality 95 for exact name match)
      # Age: Trestle should win with higher quality score
      assert result.composed_data.age == "35-44"
      assert result.data_sources.age == "trestle"

      # Demographics: Faraday should be selected based on field capabilities
      assert result.composed_data.household_income == 95_000
      assert result.composed_data.education == "Bachelor's Degree"
      assert result.data_sources.household_income == "faraday"
      assert result.data_sources.education == "faraday"
    end

    test "handles provider quality scoring through protocol" do
      # Trestle with high quality score vs Faraday with low quality score
      provider_data = [
        %ProviderData{
          provider_type: "trestle",
          status: "success",
          enrichment_data: %{
            first_name: "John",
            last_name: "Smith",
            age_range: "35-44"
          },
          quality_metadata: %{match_count: 1, name_hint: "John Smith"},
          received_at: NaiveDateTime.utc_now()
        },
        %ProviderData{
          provider_type: "faraday",
          status: "success",
          enrichment_data: %{age: 40},
          quality_metadata: %{match_type: "email_only"},
          received_at: NaiveDateTime.utc_now()
        }
      ]

      result = Composer.compose(provider_data, :default, "test-enrichment-id")

      # Should use Trestle age_range due to higher quality score (95 vs 10)
      assert result.composed_data.age == "35-44"
      assert result.data_sources.age == "trestle"
    end

    test "uses field capabilities from protocol for provider selection" do
      provider_data = [
        %ProviderData{
          provider_type: "trestle",
          status: "success",
          enrichment_data: %{
            first_name: "John",
            age_range: "35-44"
          },
          quality_metadata: %{match_count: 1, name_hint: nil},
          received_at: NaiveDateTime.utc_now()
        },
        %ProviderData{
          provider_type: "faraday",
          status: "success",
          enrichment_data: %{
            household_income: 85_000,
            has_pet: true,
            ptt: 75
          },
          quality_metadata: %{match_type: "address_full_name"},
          received_at: NaiveDateTime.utc_now()
        }
      ]

      result = Composer.compose(provider_data, :default, "test-enrichment-id")

      # Should select providers based on field capabilities
      # Trestle for contact fields (first_name, age)
      assert result.composed_data.first_name == "John"
      assert result.composed_data.age == "35-44"
      assert result.data_sources.first_name == "trestle"
      assert result.data_sources.age == "trestle"

      # Faraday for demographic/lifestyle fields
      assert result.composed_data.household_income == 85_000
      assert result.composed_data.has_pet == true
      assert result.composed_data.ptt == 75
      assert result.data_sources.household_income == "faraday"
      assert result.data_sources.has_pet == "faraday"
      assert result.data_sources.ptt == "faraday"
    end

    test "works with normalized data from protocol" do
      provider_data = [
        %ProviderData{
          provider_type: "trestle",
          status: "success",
          enrichment_data: %{
            addresses: [
              %{city: "Columbus", state: "OH", street_1: "123 Main St", zip: "43215"},
              %{city: "Dublin", state: "OH", street_1: "456 Oak Ave", zip: "43017"}
            ],
            emails: ["primary@example.com", "secondary@example.com"]
          },
          quality_metadata: %{match_count: 1, name_hint: nil},
          received_at: NaiveDateTime.utc_now()
        }
      ]

      result = Composer.compose(provider_data, :default, "test-enrichment-id")

      # Should extract first address from addresses list through protocol
      assert result.composed_data.city == "Columbus"
      assert result.composed_data.state == "OH"
      assert result.composed_data.street_1 == "123 Main St"
      assert result.composed_data.zip == "43215"

      # Should extract first email from emails list through protocol
      assert result.composed_data.email == "primary@example.com"

      # All should be sourced from Trestle
      assert result.data_sources.city == "trestle"
      assert result.data_sources.state == "trestle"
      assert result.data_sources.street_1 == "trestle"
      assert result.data_sources.zip == "trestle"
      assert result.data_sources.email == "trestle"
    end
  end

  describe "address field selection (Faraday preference)" do
    test "prefers Faraday for address fields when both providers have data" do
      provider_data = [
        %ProviderData{
          provider_type: "trestle",
          status: "success",
          enrichment_data: %{
            addresses: [
              %{
                city: "Columbus",
                state: "OH",
                street_1: "123 Main St",
                street_2: "Apt 4B",
                zip: "43215"
              }
            ]
          },
          quality_metadata: %{match_count: 1},
          received_at: NaiveDateTime.utc_now()
        },
        %ProviderData{
          provider_type: "faraday",
          status: "success",
          enrichment_data: %{
            city: "CHICAGO",
            state: "IL",
            address: "456 ELM STREET",
            postcode: "60601"
          },
          quality_metadata: %{match_type: "address_full_name"},
          received_at: NaiveDateTime.utc_now()
        }
      ]

      result = Composer.compose(provider_data, :default, "test-enrichment-id")

      # Should prefer Faraday for address fields (demographic data is based on this address)
      assert result.composed_data.city == "CHICAGO"
      assert result.composed_data.state == "IL"
      assert result.composed_data.street_1 == "456 ELM STREET"
      assert result.composed_data.zip == "60601"

      # Data sources should be Faraday for fields it has
      assert result.data_sources.city == "faraday"
      assert result.data_sources.state == "faraday"
      assert result.data_sources.street_1 == "faraday"
      assert result.data_sources.zip == "faraday"

      # street_2 only exists in Trestle, so it comes from there
      assert result.composed_data.street_2 == "Apt 4B"
      assert result.data_sources.street_2 == "trestle"
    end

    test "falls back to Trestle when Faraday doesn't have address data" do
      provider_data = [
        %ProviderData{
          provider_type: "trestle",
          status: "success",
          enrichment_data: %{
            addresses: [
              %{
                city: "Columbus",
                state: "OH",
                street_1: "123 Main St",
                zip: "43215"
              }
            ]
          },
          quality_metadata: %{match_count: 1},
          received_at: NaiveDateTime.utc_now()
        },
        %ProviderData{
          provider_type: "faraday",
          status: "success",
          enrichment_data: %{
            # No address fields
            household_income: 75_000
          },
          quality_metadata: %{match_type: "phone_full_name"},
          received_at: NaiveDateTime.utc_now()
        }
      ]

      result = Composer.compose(provider_data, :default, "test-enrichment-id")

      # Should fall back to Trestle when Faraday lacks address data
      assert result.composed_data.city == "Columbus"
      assert result.composed_data.state == "OH"
      assert result.composed_data.street_1 == "123 Main St"
      assert result.composed_data.zip == "43215"

      # Data sources should be Trestle
      assert result.data_sources.city == "trestle"
      assert result.data_sources.state == "trestle"
      assert result.data_sources.street_1 == "trestle"
      assert result.data_sources.zip == "trestle"
    end

    test "uses Trestle when only Trestle has address data" do
      provider_data = [
        %ProviderData{
          provider_type: "trestle",
          status: "success",
          enrichment_data: %{
            addresses: [
              %{
                city: "Boston",
                state: "MA",
                street_1: "321 Pine St",
                zip: "02108"
              }
            ],
            first_name: "John"
          },
          quality_metadata: %{match_count: 1},
          received_at: NaiveDateTime.utc_now()
        }
      ]

      result = Composer.compose(provider_data, :default, "test-enrichment-id")

      # Should use Trestle address data
      assert result.composed_data.city == "Boston"
      assert result.composed_data.state == "MA"
      assert result.composed_data.street_1 == "321 Pine St"
      assert result.composed_data.zip == "02108"

      # All address fields should be from Trestle
      assert result.data_sources.city == "trestle"
      assert result.data_sources.state == "trestle"
      assert result.data_sources.street_1 == "trestle"
      assert result.data_sources.zip == "trestle"
    end

    test "uses Faraday when only Faraday has address data" do
      provider_data = [
        %ProviderData{
          provider_type: "faraday",
          status: "success",
          enrichment_data: %{
            city: "DENVER",
            state: "CO",
            address: "789 Oak Ave",
            postcode: "80202"
          },
          quality_metadata: %{match_type: "address_full_name"},
          received_at: NaiveDateTime.utc_now()
        }
      ]

      result = Composer.compose(provider_data, :default, "test-enrichment-id")

      # Should use Faraday address data (normalized to street_1/zip)
      assert result.composed_data.city == "DENVER"
      assert result.composed_data.state == "CO"
      assert result.composed_data.street_1 == "789 Oak Ave"
      assert result.composed_data.zip == "80202"

      # All address fields should be from Faraday
      assert result.data_sources.city == "faraday"
      assert result.data_sources.state == "faraday"
      assert result.data_sources.street_1 == "faraday"
      assert result.data_sources.zip == "faraday"
    end
  end
end
