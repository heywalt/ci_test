defmodule CQRS.Enrichments.Data.ProviderDataTest do
  use ExUnit.Case, async: true

  alias CQRS.Enrichments.Data.ProviderData

  describe "validate/1" do
    test "returns :ok for valid success data" do
      valid_data = %ProviderData{
        provider_type: "faraday",
        status: "success",
        enrichment_data: %{age: 30, income: 50_000},
        quality_metadata: %{match_type: "address_full_name"},
        received_at: NaiveDateTime.utc_now()
      }

      assert ProviderData.validate(valid_data) == :ok
    end

    test "returns :ok for valid error data" do
      valid_data = %ProviderData{
        provider_type: "trestle",
        status: "error",
        error_data: %{reason: "rate_limit"},
        received_at: NaiveDateTime.utc_now()
      }

      assert ProviderData.validate(valid_data) == :ok
    end

    test "returns error for invalid provider_type" do
      invalid_data = %ProviderData{
        provider_type: "invalid",
        status: "success",
        enrichment_data: %{age: 30},
        received_at: NaiveDateTime.utc_now()
      }

      assert {:error, errors} = ProviderData.validate(invalid_data)
      assert Keyword.has_key?(errors, :provider_type)
    end

    test "returns error for invalid status" do
      invalid_data = %ProviderData{
        provider_type: "faraday",
        status: "invalid",
        enrichment_data: %{age: 30},
        received_at: NaiveDateTime.utc_now()
      }

      assert {:error, errors} = ProviderData.validate(invalid_data)
      assert Keyword.has_key?(errors, :status)
    end

    test "returns error for success status without enrichment_data" do
      invalid_data = %ProviderData{
        provider_type: "faraday",
        status: "success",
        received_at: NaiveDateTime.utc_now()
      }

      assert {:error, errors} = ProviderData.validate(invalid_data)
      assert Keyword.has_key?(errors, :enrichment_data)
    end

    test "returns error for error status without error_data" do
      invalid_data = %ProviderData{
        provider_type: "faraday",
        status: "error",
        received_at: NaiveDateTime.utc_now()
      }

      assert {:error, errors} = ProviderData.validate(invalid_data)
      assert Keyword.has_key?(errors, :error_data)
    end
  end
end
