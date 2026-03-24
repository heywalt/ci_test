defmodule CQRS.Enrichments.Commands.CompleteProviderEnrichmentTest do
  use ExUnit.Case, async: true

  alias CQRS.Enrichments.Commands.CompleteProviderEnrichment

  describe "new/1" do
    test "creates command with provided timestamp" do
      timestamp = NaiveDateTime.utc_now()

      attrs = %{
        id: Ecto.UUID.generate(),
        provider_type: "faraday",
        status: "success",
        enrichment_data: %{age: 30},
        timestamp: timestamp
      }

      command = CompleteProviderEnrichment.new(attrs)

      assert command.id == attrs.id
      assert command.provider_type == "faraday"
      assert command.status == "success"
      assert command.enrichment_data == %{age: 30}
      assert command.timestamp == timestamp
    end

    test "creates command with generated timestamp when not provided" do
      attrs = %{
        id: Ecto.UUID.generate(),
        provider_type: "faraday",
        status: "success",
        enrichment_data: %{age: 30}
      }

      command = CompleteProviderEnrichment.new(attrs)

      assert command.id == attrs.id
      assert command.provider_type == "faraday"
      assert command.status == "success"
      assert command.enrichment_data == %{age: 30}
      assert %NaiveDateTime{} = command.timestamp
    end
  end

  describe "CQRS.Certifiable" do
    test "validates successfully with valid success data" do
      command =
        CompleteProviderEnrichment.new(%{
          id: Ecto.UUID.generate(),
          provider_type: "faraday",
          status: "success",
          enrichment_data: %{age: 30},
          quality_metadata: %{match_type: "address_full_name"}
        })

      assert :ok = CQRS.Certifiable.certify(command)
    end

    test "validates successfully with valid error data" do
      command =
        CompleteProviderEnrichment.new(%{
          id: Ecto.UUID.generate(),
          provider_type: "trestle",
          status: "error",
          error_data: %{reason: "rate_limit"}
        })

      assert :ok = CQRS.Certifiable.certify(command)
    end

    test "fails validation when id is nil" do
      command =
        CompleteProviderEnrichment.new(%{
          id: Ecto.UUID.generate(),
          provider_type: "faraday",
          status: "success",
          enrichment_data: %{age: 30}
        })

      command_with_nil_id = %{command | id: nil}

      assert {:error, errors} = CQRS.Certifiable.certify(command_with_nil_id)
      assert Keyword.has_key?(errors, :id)
    end

    test "fails validation when provider_type is nil" do
      command =
        CompleteProviderEnrichment.new(%{
          id: Ecto.UUID.generate(),
          provider_type: "faraday",
          status: "success",
          enrichment_data: %{age: 30}
        })

      command_with_nil_provider = %{command | provider_type: nil}

      assert {:error, errors} = CQRS.Certifiable.certify(command_with_nil_provider)
      assert Keyword.has_key?(errors, :provider_type)
    end

    test "fails validation when status is nil" do
      command =
        CompleteProviderEnrichment.new(%{
          id: Ecto.UUID.generate(),
          provider_type: "faraday",
          status: "success",
          enrichment_data: %{age: 30}
        })

      command_with_nil_status = %{command | status: nil}

      assert {:error, errors} = CQRS.Certifiable.certify(command_with_nil_status)
      assert Keyword.has_key?(errors, :status)
    end

    test "fails validation when provider_type is invalid" do
      command =
        CompleteProviderEnrichment.new(%{
          id: Ecto.UUID.generate(),
          provider_type: "invalid",
          status: "success",
          enrichment_data: %{age: 30}
        })

      assert {:error, errors} = CQRS.Certifiable.certify(command)
      assert {"must be one of: faraday, trestle", []} = errors[:provider_type]
    end

    test "fails validation when status is invalid" do
      command =
        CompleteProviderEnrichment.new(%{
          id: Ecto.UUID.generate(),
          provider_type: "faraday",
          status: "invalid",
          enrichment_data: %{age: 30}
        })

      assert {:error, errors} = CQRS.Certifiable.certify(command)
      assert {"must be either: success, error", []} = errors[:status]
    end
  end
end
