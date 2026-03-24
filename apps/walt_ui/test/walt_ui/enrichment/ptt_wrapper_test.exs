defmodule WaltUi.Enrichment.PttWrapperTest do
  use ExUnit.Case, async: true

  alias CQRS.Enrichments.Data.ProviderData
  alias WaltUi.Enrichment.PttWrapper

  describe "adjust/2" do
    # Basic Functionality Tests

    test "with no adjustments needed" do
      faraday_data =
        build_provider_data(:faraday, %{
          homeowner_status: "Definite Owner",
          street_1: "123 Main St",
          city: "Austin",
          state: "TX",
          zip: "78701"
        })

      trestle_data =
        build_provider_data(:trestle, %{
          street_1: "123 Main St",
          city: "Austin",
          state: "TX",
          zip: "78701"
        })

      assert PttWrapper.adjust(100, [faraday_data, trestle_data]) == 100
    end

    test "with missing Move Score in composed data" do
      provider_data = [build_provider_data(:faraday, %{})]
      assert PttWrapper.adjust(nil, provider_data) == 0
    end

    # Address Mismatch Tests

    test "with address mismatch only" do
      faraday_data =
        build_provider_data(:faraday, %{
          homeowner_status: "Definite Owner",
          street_1: "456 Oak Ave",
          city: "Austin",
          state: "TX",
          zip: "78701"
        })

      trestle_data =
        build_provider_data(:trestle, %{
          street_1: "123 Main St",
          city: "Austin",
          state: "TX",
          zip: "78701"
        })

      assert PttWrapper.adjust(100, [faraday_data, trestle_data]) == 50
    end

    test "with address mismatch - different street only" do
      faraday_data =
        build_provider_data(:faraday, %{
          street_1: "456 Oak Ave",
          city: "Austin",
          state: "TX",
          zip: "78701"
        })

      trestle_data =
        build_provider_data(:trestle, %{
          street_1: "123 Main St",
          city: "Austin",
          state: "TX",
          zip: "78701"
        })

      assert PttWrapper.adjust(80, [faraday_data, trestle_data]) == 40
    end

    test "with different street_2 values" do
      faraday_data =
        build_provider_data(:faraday, %{
          street_1: "123 Main St",
          street_2: "Apt 4B",
          city: "Austin",
          state: "TX",
          zip: "78701"
        })

      trestle_data =
        build_provider_data(:trestle, %{
          street_1: "123 Main St",
          street_2: "Unit 5",
          city: "Austin",
          state: "TX",
          zip: "78701"
        })

      # street_2 differences should be ignored
      assert PttWrapper.adjust(100, [faraday_data, trestle_data]) == 100
    end

    test "with address mismatch - case differences" do
      faraday_data =
        build_provider_data(:faraday, %{
          street_1: "123 MAIN ST",
          city: "AUSTIN",
          state: "TX",
          zip: "78701"
        })

      trestle_data =
        build_provider_data(:trestle, %{
          street_1: "123 Main St",
          city: "Austin",
          state: "TX",
          zip: "78701"
        })

      # Case should be normalized
      assert PttWrapper.adjust(100, [faraday_data, trestle_data]) == 100
    end

    test "with address mismatch - missing Trestle address" do
      faraday_data =
        build_provider_data(:faraday, %{
          street_1: "123 Main St",
          city: "Austin",
          state: "TX",
          zip: "78701"
        })

      # No Trestle data means no comparison possible
      assert PttWrapper.adjust(100, [faraday_data]) == 100
    end

    # Renter Tests

    test "with renter status only" do
      faraday_data =
        build_provider_data(:faraday, %{
          homeowner_status: "Definite Renter",
          street_1: "123 Main St",
          city: "Austin",
          state: "TX",
          zip: "78701"
        })

      trestle_data =
        build_provider_data(:trestle, %{
          street_1: "123 Main St",
          city: "Austin",
          state: "TX",
          zip: "78701"
        })

      assert PttWrapper.adjust(100, [faraday_data, trestle_data]) == 80
    end

    test "with probable renter" do
      faraday_data =
        build_provider_data(:faraday, %{
          homeowner_status: "Probable Renter",
          street_1: "123 Main St",
          city: "Austin",
          state: "TX",
          zip: "78701"
        })

      trestle_data =
        build_provider_data(:trestle, %{
          street_1: "123 Main St",
          city: "Austin",
          state: "TX",
          zip: "78701"
        })

      assert PttWrapper.adjust(100, [faraday_data, trestle_data]) == 80
    end

    test "with owner status" do
      faraday_data =
        build_provider_data(:faraday, %{
          homeowner_status: "Probable Owner"
        })

      assert PttWrapper.adjust(100, [faraday_data]) == 100
    end

    # Stacking Tests

    test "with both conditions" do
      faraday_data =
        build_provider_data(:faraday, %{
          homeowner_status: "Definite Renter",
          street_1: "456 Oak Ave",
          city: "Austin",
          state: "TX",
          zip: "78701"
        })

      trestle_data =
        build_provider_data(:trestle, %{
          street_1: "123 Main St",
          city: "Austin",
          state: "TX",
          zip: "78701"
        })

      # 100 * 0.5 * 0.8 = 40
      assert PttWrapper.adjust(100, [faraday_data, trestle_data]) == 40
    end

    test "with both conditions - low initial Move Score" do
      faraday_data =
        build_provider_data(:faraday, %{
          homeowner_status: "Definite Renter",
          street_1: "456 Oak Ave",
          city: "Austin",
          state: "TX",
          zip: "78701"
        })

      trestle_data =
        build_provider_data(:trestle, %{
          street_1: "123 Main St",
          city: "Austin",
          state: "TX",
          zip: "78701"
        })

      # 3 * 0.5 * 0.8 = 1.2, rounded to 1 (minimum)
      assert PttWrapper.adjust(3, [faraday_data, trestle_data]) == 1
    end

    # Minimum Move Score Tests

    test "enforces minimum Move Score of 1 for positive values" do
      faraday_data =
        build_provider_data(:faraday, %{
          homeowner_status: "Definite Renter",
          street_1: "456 Oak Ave"
        })

      trestle_data =
        build_provider_data(:trestle, %{
          street_1: "123 Main St"
        })

      # 2 * 0.5 * 0.8 = 0.8, but minimum is 1
      assert PttWrapper.adjust(2, [faraday_data, trestle_data]) == 1
    end

    test "with zero initial Move Score" do
      faraday_data =
        build_provider_data(:faraday, %{
          homeowner_status: "Definite Renter"
        })

      # Zero stays zero
      assert PttWrapper.adjust(0, [faraday_data]) == 0
    end

    test "with very low Move Score" do
      faraday_data =
        build_provider_data(:faraday, %{
          homeowner_status: "Definite Renter"
        })

      # 1 * 0.8 = 0.8, but minimum is 1
      assert PttWrapper.adjust(1, [faraday_data]) == 1
    end

    # Edge Cases

    test "with nil provider data" do
      assert PttWrapper.adjust(100, [nil]) == 100
    end

    test "with nil address fields" do
      faraday_data =
        build_provider_data(:faraday, %{
          street_1: nil,
          city: "Austin",
          state: "TX",
          zip: "78701"
        })

      trestle_data =
        build_provider_data(:trestle, %{
          street_1: "123 Main St",
          city: "Austin",
          state: nil,
          zip: "78701"
        })

      # Different non-nil fields = mismatch
      assert PttWrapper.adjust(100, [faraday_data, trestle_data]) == 50
    end

    test "with nil homeowner_status" do
      faraday_data =
        build_provider_data(:faraday, %{
          homeowner_status: nil
        })

      # No renter reduction applied
      assert PttWrapper.adjust(100, [faraday_data]) == 100
    end

    test "with empty provider list" do
      assert PttWrapper.adjust(100, []) == 100
    end

    test "with non-integer Move Score" do
      faraday_data = build_provider_data(:faraday, %{})

      # Should handle floats gracefully
      assert PttWrapper.adjust(50.5, [faraday_data]) == 51
      assert PttWrapper.adjust(50.4, [faraday_data]) == 50
    end
  end

  # Helper to build ProviderData structs
  defp build_provider_data(provider_type, enrichment_data) do
    %ProviderData{
      provider_type: to_string(provider_type),
      status: "success",
      enrichment_data: enrichment_data,
      quality_metadata: %{},
      error_data: nil,
      received_at: ~N[2024-01-01 00:00:00]
    }
  end
end
