defmodule CQRS.Enrichments.Commands.RequestProviderEnrichmentTest do
  use ExUnit.Case, async: true

  alias CQRS.Enrichments.Commands.RequestProviderEnrichment

  describe "new/1" do
    test "creates command with provided timestamp" do
      timestamp = NaiveDateTime.utc_now()

      attrs = %{
        id: Ecto.UUID.generate(),
        provider_type: "faraday",
        contact_data: %{name: "John Doe"},
        timestamp: timestamp
      }

      command = RequestProviderEnrichment.new(attrs)

      assert command.id == attrs.id
      assert command.provider_type == "faraday"
      assert command.contact_data == %{name: "John Doe"}
      assert command.timestamp == timestamp
    end

    test "creates command with generated timestamp when not provided" do
      attrs = %{
        id: Ecto.UUID.generate(),
        provider_type: "faraday",
        contact_data: %{name: "John Doe"}
      }

      command = RequestProviderEnrichment.new(attrs)

      assert command.id == attrs.id
      assert command.provider_type == "faraday"
      assert command.contact_data == %{name: "John Doe"}
      assert %NaiveDateTime{} = command.timestamp
    end
  end

  describe "CQRS.Certifiable" do
    test "validates successfully with valid data" do
      command =
        RequestProviderEnrichment.new(%{
          id: Ecto.UUID.generate(),
          provider_type: "faraday",
          contact_data: %{name: "John Doe"},
          provider_config: %{api_key: "test"}
        })

      assert :ok = CQRS.Certifiable.certify(command)
    end

    test "fails validation when id is nil" do
      command =
        RequestProviderEnrichment.new(%{
          id: Ecto.UUID.generate(),
          provider_type: "faraday",
          contact_data: %{name: "John Doe"}
        })

      command_with_nil_id = %{command | id: nil}

      assert {:error, errors} = CQRS.Certifiable.certify(command_with_nil_id)
      assert Keyword.has_key?(errors, :id)
    end

    test "fails validation when provider_type is nil" do
      command =
        RequestProviderEnrichment.new(%{
          id: Ecto.UUID.generate(),
          provider_type: "faraday",
          contact_data: %{name: "John Doe"}
        })

      command_with_nil_provider = %{command | provider_type: nil}

      assert {:error, errors} = CQRS.Certifiable.certify(command_with_nil_provider)
      assert Keyword.has_key?(errors, :provider_type)
    end

    test "fails validation when contact_data is nil" do
      command =
        RequestProviderEnrichment.new(%{
          id: Ecto.UUID.generate(),
          provider_type: "faraday",
          contact_data: %{name: "John Doe"}
        })

      command_with_nil_contact_data = %{command | contact_data: nil}

      assert {:error, errors} = CQRS.Certifiable.certify(command_with_nil_contact_data)
      assert Keyword.has_key?(errors, :contact_data)
    end

    test "fails validation when provider_type is invalid" do
      command =
        RequestProviderEnrichment.new(%{
          id: Ecto.UUID.generate(),
          provider_type: "invalid",
          contact_data: %{name: "John Doe"}
        })

      assert {:error, errors} = CQRS.Certifiable.certify(command)
      assert {"must be one of: faraday, trestle", []} = errors[:provider_type]
    end
  end
end
