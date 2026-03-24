defmodule CQRS.Enrichments.Events.EnrichmentComposedTest do
  use ExUnit.Case, async: true

  alias CQRS.Enrichments.Events.EnrichmentComposed

  describe "new/1" do
    test "creates event with all required fields" do
      attrs = %{
        id: Ecto.UUID.generate(),
        composed_data: %{
          email: "john@example.com",
          first_name: "John",
          last_name: "Doe",
          phone: "1234567890",
          age: 30,
          age_range: "25-34",
          income: 75_000,
          addresses: [
            %{
              street: "123 Main St",
              city: "Austin",
              state: "TX",
              zip: "78701"
            }
          ]
        },
        data_sources: %{
          age: :faraday,
          age_range: :trestle,
          income: :faraday,
          addresses: :trestle,
          first_name: :trestle,
          last_name: :trestle,
          email: :original,
          phone: :original
        },
        provider_scores: %{
          faraday: 95,
          trestle: 85
        },
        phone: "1234567890"
      }

      event = EnrichmentComposed.new(attrs)

      assert event.id == attrs.id
      assert event.composed_data == attrs.composed_data
      assert event.data_sources == attrs.data_sources
      assert event.phone == "1234567890"
      assert event.version == 1
      assert %NaiveDateTime{} = event.timestamp
    end

    test "sets timestamp to current time when not provided" do
      attrs = %{
        id: Ecto.UUID.generate(),
        composed_data: %{},
        data_sources: %{},
        provider_scores: %{},
        phone: "5551234567"
      }

      before = NaiveDateTime.truncate(NaiveDateTime.utc_now(), :second)
      event = EnrichmentComposed.new(attrs)
      after_time = NaiveDateTime.truncate(NaiveDateTime.utc_now(), :second)

      assert NaiveDateTime.compare(event.timestamp, before) in [:gt, :eq]
      assert NaiveDateTime.compare(event.timestamp, after_time) in [:lt, :eq]
    end

    test "preserves custom timestamp when provided" do
      custom_timestamp = ~N[2023-01-01 12:00:00]

      attrs = %{
        id: Ecto.UUID.generate(),
        composed_data: %{},
        data_sources: %{},
        provider_scores: %{},
        phone: "9876543210",
        timestamp: custom_timestamp
      }

      event = EnrichmentComposed.new(attrs)

      assert event.timestamp == custom_timestamp
    end

    test "requires phone field" do
      attrs = %{
        id: Ecto.UUID.generate(),
        composed_data: %{},
        data_sources: %{},
        provider_scores: %{}
        # phone field missing
      }

      assert_raise ArgumentError, fn ->
        EnrichmentComposed.new(attrs)
      end
    end

    test "accepts valid ten-digit phone" do
      attrs = %{
        id: Ecto.UUID.generate(),
        composed_data: %{},
        data_sources: %{},
        provider_scores: %{},
        phone: "1234567890"
      }

      event = EnrichmentComposed.new(attrs)

      assert event.phone == "1234567890"
    end
  end
end
