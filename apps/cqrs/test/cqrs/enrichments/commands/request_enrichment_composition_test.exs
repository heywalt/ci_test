defmodule CQRS.Enrichments.Commands.RequestEnrichmentCompositionTest do
  use ExUnit.Case, async: true

  alias CQRS.Enrichments.Commands.RequestEnrichmentComposition
  alias CQRS.Enrichments.Data.ProviderData

  describe "new/1" do
    test "creates command with all required fields" do
      provider_data = [
        %{
          provider_type: "trestle",
          status: "success",
          enrichment_data: %{age_range: "25-34"},
          quality_metadata: %{match_score: 0.95},
          received_at: NaiveDateTime.utc_now()
        },
        %{
          provider_type: "faraday",
          status: "success",
          enrichment_data: %{age: 30},
          quality_metadata: %{match_type: "address_full_name"},
          received_at: NaiveDateTime.utc_now()
        }
      ]

      attrs = %{
        id: Ecto.UUID.generate(),
        provider_data: provider_data,
        composition_rules: :quality_based
      }

      command = RequestEnrichmentComposition.new(attrs)

      # Convert expected provider_data to ProviderData structs for comparison
      expected_provider_data = Enum.map(attrs.provider_data, &struct(ProviderData, &1))

      assert command.id == attrs.id
      assert command.provider_data == expected_provider_data
      assert command.composition_rules == attrs.composition_rules
      assert command.version == 1
      assert %NaiveDateTime{} = command.timestamp
    end

    test "sets timestamp to current time when not provided" do
      attrs = %{
        id: Ecto.UUID.generate(),
        provider_data: [],
        composition_rules: :default
      }

      before = NaiveDateTime.truncate(NaiveDateTime.utc_now(), :second)
      command = RequestEnrichmentComposition.new(attrs)
      after_time = NaiveDateTime.truncate(NaiveDateTime.utc_now(), :second)

      assert NaiveDateTime.compare(command.timestamp, before) in [:gt, :eq]
      assert NaiveDateTime.compare(command.timestamp, after_time) in [:lt, :eq]
    end

    test "preserves custom timestamp when provided" do
      custom_timestamp = ~N[2023-01-01 12:00:00]

      attrs = %{
        id: Ecto.UUID.generate(),
        provider_data: [],
        composition_rules: :default,
        timestamp: custom_timestamp
      }

      command = RequestEnrichmentComposition.new(attrs)

      assert command.timestamp == custom_timestamp
    end
  end

  describe "CQRS.Certifiable" do
    test "validates command with valid data" do
      command =
        RequestEnrichmentComposition.new(%{
          id: Ecto.UUID.generate(),
          provider_data: [
            %{
              provider_type: "trestle",
              status: "success",
              enrichment_data: %{age_range: "25-34"},
              quality_metadata: %{},
              received_at: NaiveDateTime.utc_now()
            }
          ],
          composition_rules: :default
        })

      assert :ok = CQRS.Certifiable.certify(command)
    end

    test "fails validation with empty provider data" do
      command =
        RequestEnrichmentComposition.new(%{
          id: Ecto.UUID.generate(),
          provider_data: [],
          composition_rules: :default
        })

      assert {:error, errors} = CQRS.Certifiable.certify(command)

      assert Enum.any?(errors, fn {field, {msg, _}} ->
               field == :provider_data and msg == "must have at least one provider result"
             end)
    end

    test "requires id" do
      command = %RequestEnrichmentComposition{
        id: nil,
        provider_data: [],
        composition_rules: :default,
        timestamp: NaiveDateTime.utc_now()
      }

      assert {:error, errors} = CQRS.Certifiable.certify(command)
      assert {:id, {"can't be blank", [validation: :required]}} in errors
    end

    test "requires composition_rules" do
      command = %RequestEnrichmentComposition{
        id: Ecto.UUID.generate(),
        provider_data: [],
        composition_rules: nil,
        timestamp: NaiveDateTime.utc_now()
      }

      assert {:error, errors} = CQRS.Certifiable.certify(command)
      assert {:composition_rules, {"can't be blank", [validation: :required]}} in errors
    end

    test "requires timestamp" do
      command = %RequestEnrichmentComposition{
        id: Ecto.UUID.generate(),
        provider_data: [],
        composition_rules: :default,
        timestamp: nil
      }

      assert {:error, errors} = CQRS.Certifiable.certify(command)
      assert {:timestamp, {"can't be blank", [validation: :required]}} in errors
    end

    test "validates composition_rules is a valid atom" do
      command = %RequestEnrichmentComposition{
        id: Ecto.UUID.generate(),
        provider_data: [],
        composition_rules: :unknown_rule_set,
        timestamp: NaiveDateTime.utc_now()
      }

      assert {:error, errors} = CQRS.Certifiable.certify(command)

      assert {:composition_rules,
              {"is invalid", [validation: :inclusion, enum: [:default, :quality_based]]}} in errors
    end

    test "validates provider_data entries" do
      # Just test that invalid provider data is caught - the details are tested in ProviderData
      command = %RequestEnrichmentComposition{
        id: Ecto.UUID.generate(),
        provider_data: [
          %{
            # Missing required fields - should fail validation
            provider_type: "trestle"
          }
        ],
        composition_rules: :default,
        timestamp: NaiveDateTime.utc_now()
      }

      assert {:error, errors} = CQRS.Certifiable.certify(command)
      # Just check that provider_data validation failed
      assert Enum.any?(errors, fn {field, _} -> field == :provider_data end)
    end
  end
end
