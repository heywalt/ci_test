defmodule CQRS.Enrichments.Events.EnrichmentCompositionRequestedTest do
  use ExUnit.Case, async: true

  alias CQRS.Enrichments.Events.EnrichmentCompositionRequested

  describe "new/1" do
    test "creates event with all required fields" do
      attrs = %{
        id: Ecto.UUID.generate(),
        provider_data: [
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
        ],
        composition_rules: :quality_based
      }

      event = EnrichmentCompositionRequested.new(attrs)

      assert event.id == attrs.id
      assert event.provider_data == attrs.provider_data
      assert event.composition_rules == attrs.composition_rules
      assert event.version == 1
      assert %NaiveDateTime{} = event.timestamp
    end

    test "sets timestamp to current time when not provided" do
      attrs = %{
        id: Ecto.UUID.generate(),
        provider_data: [],
        composition_rules: :default
      }

      before = NaiveDateTime.truncate(NaiveDateTime.utc_now(), :second)
      event = EnrichmentCompositionRequested.new(attrs)
      after_time = NaiveDateTime.truncate(NaiveDateTime.utc_now(), :second)

      assert NaiveDateTime.compare(event.timestamp, before) in [:gt, :eq]
      assert NaiveDateTime.compare(event.timestamp, after_time) in [:lt, :eq]
    end

    test "preserves custom timestamp when provided" do
      custom_timestamp = ~N[2023-01-01 12:00:00]

      attrs = %{
        id: Ecto.UUID.generate(),
        provider_data: [],
        composition_rules: :default,
        timestamp: custom_timestamp
      }

      event = EnrichmentCompositionRequested.new(attrs)

      assert event.timestamp == custom_timestamp
    end
  end
end
