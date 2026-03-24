defmodule WaltUi.Enrichment.ComposableTest do
  use ExUnit.Case, async: true

  alias CQRS.Enrichments.Data.ProviderData
  alias WaltUi.Enrichment.Composable

  describe "Composable protocol" do
    test "normalize_data/1 is implemented for Trestle provider" do
      provider_data = %ProviderData{
        provider_type: "trestle",
        status: "success",
        enrichment_data: %{
          first_name: "John",
          age_range: "35-44",
          addresses: [
            %{city: "Columbus", state: "OH", street_1: "123 Main St", zip: "43215"}
          ]
        },
        quality_metadata: %{match_count: 1, name_hint: nil},
        received_at: NaiveDateTime.utc_now()
      }

      normalized = Composable.normalize_data(provider_data)

      assert is_map(normalized)
      assert normalized.first_name == "John"
      # age_range mapped to age
      assert normalized.age == "35-44"
      assert normalized.city == "Columbus"
    end

    test "normalize_data/1 is implemented for Faraday provider" do
      provider_data = %ProviderData{
        provider_type: "faraday",
        status: "success",
        enrichment_data: %{
          age: 35,
          city: "CHICAGO",
          state: "IL",
          household_income: 75_000
        },
        quality_metadata: %{match_type: "address_full_name"},
        received_at: NaiveDateTime.utc_now()
      }

      normalized = Composable.normalize_data(provider_data)

      assert is_map(normalized)
      assert normalized.age == 35
      assert normalized.city == "CHICAGO"
      assert normalized.household_income == 75_000
    end

    test "calculate_quality_score/1 returns integer between 0-100 for Trestle" do
      provider_data = %ProviderData{
        provider_type: "trestle",
        status: "success",
        enrichment_data: %{first_name: "John"},
        quality_metadata: %{match_count: 2, name_hint: "John Smith"},
        received_at: NaiveDateTime.utc_now()
      }

      score = Composable.calculate_quality_score(provider_data)

      assert is_integer(score)
      assert score >= 0
      assert score <= 100
    end

    test "calculate_quality_score/1 returns integer between 0-100 for Faraday" do
      provider_data = %ProviderData{
        provider_type: "faraday",
        status: "success",
        enrichment_data: %{age: 35},
        quality_metadata: %{match_type: "address_full_name"},
        received_at: NaiveDateTime.utc_now()
      }

      score = Composable.calculate_quality_score(provider_data)

      assert is_integer(score)
      assert score >= 0
      assert score <= 100
    end

    test "extract_field/2 extracts field from normalized data for Trestle" do
      provider_data = %ProviderData{
        provider_type: "trestle",
        status: "success",
        enrichment_data: %{
          first_name: "John",
          addresses: [%{city: "Columbus"}]
        },
        quality_metadata: %{match_count: 1, name_hint: nil},
        received_at: NaiveDateTime.utc_now()
      }

      assert Composable.extract_field(provider_data, :first_name) == "John"
      assert Composable.extract_field(provider_data, :city) == "Columbus"
      assert Composable.extract_field(provider_data, :missing_field) == nil
    end

    test "extract_field/2 extracts field from normalized data for Faraday" do
      provider_data = %ProviderData{
        provider_type: "faraday",
        status: "success",
        enrichment_data: %{age: 35, city: "CHICAGO"},
        quality_metadata: %{match_type: "address_full_name"},
        received_at: NaiveDateTime.utc_now()
      }

      assert Composable.extract_field(provider_data, :age) == 35
      assert Composable.extract_field(provider_data, :city) == "CHICAGO"
      assert Composable.extract_field(provider_data, :missing_field) == nil
    end

    test "get_field_capabilities/1 returns list of atoms for Trestle" do
      provider_data = %ProviderData{
        provider_type: "trestle",
        status: "success",
        enrichment_data: %{},
        quality_metadata: %{},
        received_at: NaiveDateTime.utc_now()
      }

      capabilities = Composable.get_field_capabilities(provider_data)

      assert is_list(capabilities)
      assert Enum.all?(capabilities, &is_atom/1)
      assert :first_name in capabilities
      assert :last_name in capabilities
      assert :age in capabilities
    end

    test "get_field_capabilities/1 returns list of atoms for Faraday" do
      provider_data = %ProviderData{
        provider_type: "faraday",
        status: "success",
        enrichment_data: %{},
        quality_metadata: %{},
        received_at: NaiveDateTime.utc_now()
      }

      capabilities = Composable.get_field_capabilities(provider_data)

      assert is_list(capabilities)
      assert Enum.all?(capabilities, &is_atom/1)
      assert :household_income in capabilities
      assert :education in capabilities
      assert :ptt in capabilities
    end
  end

  describe "Composable protocol for Map" do
    test "normalize_data/1 works with valid Faraday map data" do
      map_data = %{
        "provider_type" => "faraday",
        "status" => "success",
        "enrichment_data" => %{
          "age" => 35,
          "city" => "CHICAGO",
          "propensity_to_transact" => 0.65
        },
        "quality_metadata" => %{"match_type" => "address_full_name"},
        "received_at" => "2025-06-27T19:53:36"
      }

      normalized = Composable.normalize_data(map_data)

      assert is_map(normalized)
      assert normalized[:age] == 35
      assert normalized[:city] == "CHICAGO"
      assert normalized[:ptt] == 65
      refute Map.has_key?(normalized, :propensity_to_transact)
    end

    test "normalize_data/1 works with valid Trestle map data" do
      map_data = %{
        "provider_type" => "trestle",
        "status" => "success",
        "enrichment_data" => %{
          "first_name" => "John",
          "age_range" => "35-44",
          "addresses" => [
            %{"city" => "Columbus", "state" => "OH", "street_1" => "123 Main St"}
          ]
        },
        "quality_metadata" => %{"match_count" => 1},
        "received_at" => "2025-06-27T19:53:36"
      }

      normalized = Composable.normalize_data(map_data)

      assert is_map(normalized)
      assert normalized[:first_name] == "John"
      assert normalized[:age] == "35-44"
      assert normalized[:city] == "Columbus"
    end

    test "normalize_data/1 returns empty map for invalid map data" do
      invalid_map = %{"invalid" => "data"}

      normalized = Composable.normalize_data(invalid_map)

      assert normalized == %{}
    end

    test "calculate_quality_score/1 works with valid Faraday map data" do
      map_data = %{
        "provider_type" => "faraday",
        "status" => "success",
        "enrichment_data" => %{"age" => 35},
        "quality_metadata" => %{"match_type" => "address_full_name"},
        "received_at" => "2025-06-27T19:53:36"
      }

      score = Composable.calculate_quality_score(map_data)

      assert is_integer(score)
      assert score >= 0
      assert score <= 100
      assert score == 90
    end

    test "calculate_quality_score/1 works with valid Trestle map data" do
      map_data = %{
        "provider_type" => "trestle",
        "status" => "success",
        "enrichment_data" => %{"first_name" => "John"},
        "quality_metadata" => %{"match_count" => 1},
        "received_at" => "2025-06-27T19:53:36"
      }

      score = Composable.calculate_quality_score(map_data)

      assert is_integer(score)
      assert score >= 0
      assert score <= 100
    end

    test "calculate_quality_score/1 returns 0 for invalid map data" do
      invalid_map = %{"invalid" => "data"}

      score = Composable.calculate_quality_score(invalid_map)

      assert score == 0
    end

    test "extract_field/2 works with valid Faraday map data" do
      map_data = %{
        "provider_type" => "faraday",
        "status" => "success",
        "enrichment_data" => %{"age" => 35, "city" => "CHICAGO"},
        "quality_metadata" => %{"match_type" => "address_full_name"},
        "received_at" => "2025-06-27T19:53:36"
      }

      assert Composable.extract_field(map_data, :age) == 35
      assert Composable.extract_field(map_data, :city) == "CHICAGO"
      assert Composable.extract_field(map_data, :missing_field) == nil
    end

    test "extract_field/2 works with valid Trestle map data" do
      map_data = %{
        "provider_type" => "trestle",
        "status" => "success",
        "enrichment_data" => %{
          "first_name" => "John",
          "addresses" => [%{"city" => "Columbus"}]
        },
        "quality_metadata" => %{"match_count" => 1},
        "received_at" => "2025-06-27T19:53:36"
      }

      assert Composable.extract_field(map_data, :first_name) == "John"
      assert Composable.extract_field(map_data, :city) == "Columbus"
      assert Composable.extract_field(map_data, :missing_field) == nil
    end

    test "extract_field/2 returns nil for invalid map data" do
      invalid_map = %{"invalid" => "data"}

      assert Composable.extract_field(invalid_map, :any_field) == nil
    end

    test "get_field_capabilities/1 works with valid Faraday map data" do
      map_data = %{
        "provider_type" => "faraday",
        "status" => "success",
        "enrichment_data" => %{},
        "quality_metadata" => %{},
        "received_at" => "2025-06-27T19:53:36"
      }

      capabilities = Composable.get_field_capabilities(map_data)

      assert is_list(capabilities)
      assert Enum.all?(capabilities, &is_atom/1)
      assert :household_income in capabilities
      assert :ptt in capabilities
    end

    test "get_field_capabilities/1 works with valid Trestle map data" do
      map_data = %{
        "provider_type" => "trestle",
        "status" => "success",
        "enrichment_data" => %{},
        "quality_metadata" => %{},
        "received_at" => "2025-06-27T19:53:36"
      }

      capabilities = Composable.get_field_capabilities(map_data)

      assert is_list(capabilities)
      assert Enum.all?(capabilities, &is_atom/1)
      assert :first_name in capabilities
      assert :last_name in capabilities
    end

    test "get_field_capabilities/1 returns empty list for invalid map data" do
      invalid_map = %{"invalid" => "data"}

      capabilities = Composable.get_field_capabilities(invalid_map)

      assert capabilities == []
    end
  end
end
