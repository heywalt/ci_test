defmodule CQRS.Enrichments.EnrichmentAggregateTest do
  use ExUnit.Case, async: true

  alias CQRS.Enrichments.Commands.CompleteEnrichmentComposition
  alias CQRS.Enrichments.Commands.CompleteProviderEnrichment
  alias CQRS.Enrichments.Commands.Jitter
  alias CQRS.Enrichments.Commands.RequestEnrichmentComposition
  alias CQRS.Enrichments.Commands.RequestProviderEnrichment
  alias CQRS.Enrichments.Commands.Reset
  alias CQRS.Enrichments.EnrichmentAggregate
  alias CQRS.Enrichments.Events.EnrichmentComposed
  alias CQRS.Enrichments.Events.EnrichmentCompositionRequested
  alias CQRS.Enrichments.Events.EnrichmentRequested
  alias CQRS.Enrichments.Events.EnrichmentReset
  alias CQRS.Enrichments.Events.Jittered
  alias CQRS.Enrichments.Events.ProviderEnrichmentCompleted
  alias CQRS.Enrichments.Events.ProviderEnrichmentRequested

  describe "execute/2 with RequestProviderEnrichment" do
    test "creates ProviderEnrichmentRequested event for new aggregate" do
      aggregate = %EnrichmentAggregate{id: nil}

      command =
        RequestProviderEnrichment.new(%{
          id: Ecto.UUID.generate(),
          provider_type: "faraday",
          contact_data: %{first_name: "John", last_name: "Doe"},
          provider_config: %{api_key: "test"}
        })

      event = EnrichmentAggregate.execute(aggregate, command)

      assert %ProviderEnrichmentRequested{} = event
      assert event.id == command.id
      assert event.provider_type == "faraday"
      assert event.contact_data == %{first_name: "John", last_name: "Doe"}
      assert event.provider_config == %{api_key: "test"}
      assert event.timestamp == command.timestamp
    end

    test "creates ProviderEnrichmentRequested event for existing aggregate" do
      aggregate = %EnrichmentAggregate{
        id: Ecto.UUID.generate(),
        first_name: "Jane",
        last_name: "Smith"
      }

      command =
        RequestProviderEnrichment.new(%{
          id: aggregate.id,
          provider_type: "trestle",
          contact_data: %{first_name: "Jane", last_name: "Smith"}
        })

      event = EnrichmentAggregate.execute(aggregate, command)

      assert %ProviderEnrichmentRequested{} = event
      assert event.id == command.id
      assert event.provider_type == "trestle"
    end
  end

  describe "execute/2 with CompleteProviderEnrichment" do
    test "creates ProviderEnrichmentCompleted event for successful enrichment" do
      aggregate = %EnrichmentAggregate{id: Ecto.UUID.generate()}

      command =
        CompleteProviderEnrichment.new(%{
          id: aggregate.id,
          provider_type: "faraday",
          status: "success",
          enrichment_data: %{age: 30, income: 50_000},
          quality_metadata: %{match_type: "address_full_name"}
        })

      event = EnrichmentAggregate.execute(aggregate, command)

      assert %ProviderEnrichmentCompleted{} = event
      assert event.id == command.id
      assert event.provider_type == "faraday"
      assert event.status == "success"
      assert event.enrichment_data == %{age: 30, income: 50_000}
      assert event.quality_metadata == %{match_type: "address_full_name"}
    end

    test "includes phone from aggregate in ProviderEnrichmentCompleted event" do
      phone = "5551234567"

      aggregate = %EnrichmentAggregate{
        id: Ecto.UUID.generate(),
        phone: phone
      }

      command =
        CompleteProviderEnrichment.new(%{
          id: aggregate.id,
          provider_type: "faraday",
          status: "success",
          enrichment_data: %{age: 30, income: 50_000},
          quality_metadata: %{match_type: "address_full_name"}
        })

      event = EnrichmentAggregate.execute(aggregate, command)

      assert %ProviderEnrichmentCompleted{} = event
      assert event.phone == phone
    end

    test "creates ProviderEnrichmentCompleted event for failed enrichment" do
      aggregate = %EnrichmentAggregate{id: Ecto.UUID.generate()}

      command =
        CompleteProviderEnrichment.new(%{
          id: aggregate.id,
          provider_type: "trestle",
          status: "error",
          error_data: %{reason: "rate_limit", message: "Rate limit exceeded"}
        })

      event = EnrichmentAggregate.execute(aggregate, command)

      assert %ProviderEnrichmentCompleted{} = event
      assert event.id == command.id
      assert event.provider_type == "trestle"
      assert event.status == "error"
      assert event.error_data == %{reason: "rate_limit", message: "Rate limit exceeded"}
    end

    test "includes phone from aggregate in ProviderEnrichmentCompleted event for failed enrichment" do
      phone = "5551234567"

      aggregate = %EnrichmentAggregate{
        id: Ecto.UUID.generate(),
        phone: phone
      }

      command =
        CompleteProviderEnrichment.new(%{
          id: aggregate.id,
          provider_type: "endato",
          status: "error",
          error_data: %{reason: "no_data_found"}
        })

      event = EnrichmentAggregate.execute(aggregate, command)

      assert %ProviderEnrichmentCompleted{} = event
      assert event.phone == phone
      assert event.status == "error"
    end

    test "phone flows from EnrichmentRequested through to ProviderEnrichmentCompleted" do
      # Start with empty aggregate
      aggregate = %EnrichmentAggregate{}
      phone = "5551234567"

      # Apply EnrichmentRequested event (simulating RequestEnrichment command)
      enrichment_requested = %EnrichmentRequested{
        id: Ecto.UUID.generate(),
        phone: phone,
        first_name: "John",
        last_name: "Doe",
        email: "john@example.com",
        user_id: Ecto.UUID.generate(),
        timestamp: NaiveDateTime.utc_now()
      }

      aggregate = EnrichmentAggregate.apply(aggregate, enrichment_requested)
      assert aggregate.phone == phone

      # Now complete provider enrichment
      command =
        CompleteProviderEnrichment.new(%{
          id: aggregate.id,
          provider_type: "faraday",
          status: "success",
          enrichment_data: %{age: 30}
        })

      event = EnrichmentAggregate.execute(aggregate, command)

      assert %ProviderEnrichmentCompleted{} = event
      assert event.phone == phone
    end
  end

  describe "apply/2 with ProviderEnrichmentRequested" do
    test "updates aggregate state for new enrichment request" do
      aggregate = %EnrichmentAggregate{id: nil}
      timestamp = NaiveDateTime.utc_now()

      event = %ProviderEnrichmentRequested{
        id: Ecto.UUID.generate(),
        provider_type: "faraday",
        contact_data: %{first_name: "John", last_name: "Doe"},
        provider_config: %{},
        timestamp: timestamp
      }

      updated_aggregate = EnrichmentAggregate.apply(aggregate, event)

      assert updated_aggregate.id == event.id
      assert updated_aggregate.timestamp == timestamp
      assert updated_aggregate.last_provider_requested == "faraday"
      assert updated_aggregate.provider_request_timestamp == timestamp
    end

    test "updates provider tracking for existing aggregate" do
      aggregate = %EnrichmentAggregate{
        id: Ecto.UUID.generate(),
        last_provider_requested: "trestle",
        provider_request_timestamp: ~N[2024-01-01 10:00:00]
      }

      new_timestamp = ~N[2024-01-01 11:00:00]

      event = %ProviderEnrichmentRequested{
        id: aggregate.id,
        provider_type: "faraday",
        contact_data: %{},
        provider_config: %{},
        timestamp: new_timestamp
      }

      updated_aggregate = EnrichmentAggregate.apply(aggregate, event)

      assert updated_aggregate.id == aggregate.id
      assert updated_aggregate.timestamp == new_timestamp
      assert updated_aggregate.last_provider_requested == "faraday"
      assert updated_aggregate.provider_request_timestamp == new_timestamp
    end
  end

  describe "apply/2 with ProviderEnrichmentCompleted" do
    test "tracks successful provider completion" do
      aggregate = %EnrichmentAggregate{
        id: Ecto.UUID.generate(),
        first_name: "John",
        last_name: "Doe"
      }

      timestamp = NaiveDateTime.utc_now()

      event = %ProviderEnrichmentCompleted{
        id: aggregate.id,
        phone: "5551234567",
        provider_type: "faraday",
        status: "success",
        enrichment_data: %{age: 30},
        quality_metadata: %{},
        timestamp: timestamp
      }

      updated_aggregate = EnrichmentAggregate.apply(aggregate, event)

      assert updated_aggregate.id == aggregate.id
      assert updated_aggregate.first_name == aggregate.first_name
      assert updated_aggregate.last_name == aggregate.last_name
      assert updated_aggregate.timestamp == timestamp
      assert updated_aggregate.last_provider_succeeded == "faraday"
      assert updated_aggregate.provider_success_timestamp == timestamp
      assert updated_aggregate.last_provider_failed == nil
      assert updated_aggregate.provider_failure_timestamp == nil
    end

    test "tracks failed provider completion" do
      aggregate = %EnrichmentAggregate{
        id: Ecto.UUID.generate(),
        last_provider_succeeded: "faraday",
        provider_success_timestamp: ~N[2024-01-01 10:00:00]
      }

      timestamp = ~N[2024-01-01 11:00:00]

      event = %ProviderEnrichmentCompleted{
        id: aggregate.id,
        phone: "5551234567",
        provider_type: "trestle",
        status: "error",
        error_data: %{reason: "rate_limit"},
        quality_metadata: %{},
        timestamp: timestamp
      }

      updated_aggregate = EnrichmentAggregate.apply(aggregate, event)

      assert updated_aggregate.timestamp == timestamp
      assert updated_aggregate.last_provider_succeeded == "faraday"
      assert updated_aggregate.provider_success_timestamp == ~N[2024-01-01 10:00:00]
      assert updated_aggregate.last_provider_failed == "trestle"
      assert updated_aggregate.provider_failure_timestamp == timestamp
    end

    test "overwrites previous failure tracking" do
      aggregate = %EnrichmentAggregate{
        id: Ecto.UUID.generate(),
        last_provider_failed: "endato",
        provider_failure_timestamp: ~N[2024-01-01 09:00:00]
      }

      timestamp = ~N[2024-01-01 11:00:00]

      event = %ProviderEnrichmentCompleted{
        id: aggregate.id,
        phone: "5551234567",
        provider_type: "trestle",
        status: "error",
        error_data: %{reason: "timeout"},
        quality_metadata: %{},
        timestamp: timestamp
      }

      updated_aggregate = EnrichmentAggregate.apply(aggregate, event)

      assert updated_aggregate.last_provider_failed == "trestle"
      assert updated_aggregate.provider_failure_timestamp == timestamp
    end
  end

  describe "execute/2 with RequestEnrichmentComposition" do
    test "creates EnrichmentCompositionRequested event" do
      aggregate = %EnrichmentAggregate{
        id: Ecto.UUID.generate(),
        first_name: "John",
        last_name: "Doe"
      }

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

      command =
        RequestEnrichmentComposition.new(%{
          id: aggregate.id,
          provider_data: provider_data,
          composition_rules: :quality_based
        })

      event = EnrichmentAggregate.execute(aggregate, command)

      assert %EnrichmentCompositionRequested{} = event
      assert event.id == command.id
      assert event.provider_data == command.provider_data
      assert event.composition_rules == command.composition_rules
      assert event.timestamp == command.timestamp
    end
  end

  describe "apply/2 with EnrichmentComposed" do
    test "updates timestamp and last_composition_timestamp only" do
      aggregate = %EnrichmentAggregate{
        id: Ecto.UUID.generate(),
        first_name: "John",
        last_name: "Doe",
        addresses: [%{city: "Dallas", state: "TX"}]
      }

      composed_data = %{
        first_name: "John",
        last_name: "Doe",
        age: 30,
        age_range: "25-34",
        addresses: [%{city: "Austin", state: "TX"}]
      }

      data_sources = %{
        age: :faraday,
        age_range: :trestle,
        addresses: :trestle
      }

      event = %EnrichmentComposed{
        id: aggregate.id,
        composed_data: composed_data,
        data_sources: data_sources,
        provider_scores: %{faraday: 95, trestle: 85},
        phone: "1234567890",
        timestamp: NaiveDateTime.utc_now()
      }

      updated_aggregate = EnrichmentAggregate.apply(aggregate, event)

      assert updated_aggregate.timestamp == event.timestamp
      assert updated_aggregate.last_composition_timestamp == event.timestamp
      # Should not update the actual data fields
      assert updated_aggregate.first_name == aggregate.first_name
      assert updated_aggregate.last_name == aggregate.last_name
      assert updated_aggregate.addresses == aggregate.addresses
    end

    test "updates Move Score from composed_data when present" do
      aggregate = %EnrichmentAggregate{
        id: Ecto.UUID.generate(),
        ptt: 50
      }

      composed_data = %{
        first_name: "John",
        last_name: "Doe",
        ptt: 85
      }

      event = %EnrichmentComposed{
        id: aggregate.id,
        composed_data: composed_data,
        data_sources: %{},
        provider_scores: %{faraday: 95},
        phone: "1234567890",
        timestamp: NaiveDateTime.utc_now()
      }

      updated_aggregate = EnrichmentAggregate.apply(aggregate, event)

      assert updated_aggregate.ptt == 85
      assert updated_aggregate.timestamp == event.timestamp
      assert updated_aggregate.last_composition_timestamp == event.timestamp
    end

    test "preserves existing Move Score when not present in composed_data" do
      aggregate = %EnrichmentAggregate{
        id: Ecto.UUID.generate(),
        ptt: 75
      }

      composed_data = %{
        first_name: "John",
        last_name: "Doe"
        # No Move Score in composed_data
      }

      event = %EnrichmentComposed{
        id: aggregate.id,
        composed_data: composed_data,
        data_sources: %{},
        provider_scores: %{trestle: 80},
        phone: "1234567890",
        timestamp: NaiveDateTime.utc_now()
      }

      updated_aggregate = EnrichmentAggregate.apply(aggregate, event)

      # Preserved from state
      assert updated_aggregate.ptt == 75
      assert updated_aggregate.timestamp == event.timestamp
      assert updated_aggregate.last_composition_timestamp == event.timestamp
    end

    test "defaults to 0 when no Move Score in composed_data and state has nil Move Score" do
      aggregate = %EnrichmentAggregate{
        id: Ecto.UUID.generate(),
        ptt: nil
      }

      composed_data = %{
        first_name: "John",
        last_name: "Doe"
        # No Move Score in composed_data
      }

      event = %EnrichmentComposed{
        id: aggregate.id,
        composed_data: composed_data,
        data_sources: %{},
        provider_scores: %{trestle: 80},
        phone: "1234567890",
        timestamp: NaiveDateTime.utc_now()
      }

      updated_aggregate = EnrichmentAggregate.apply(aggregate, event)

      # Defaults to 0
      assert updated_aggregate.ptt == 0
      assert updated_aggregate.timestamp == event.timestamp
      assert updated_aggregate.last_composition_timestamp == event.timestamp
    end
  end

  describe "execute/2 with Reset" do
    test "creates EnrichmentReset event for existing enrichment" do
      aggregate = %EnrichmentAggregate{
        id: Ecto.UUID.generate(),
        first_name: "John",
        last_name: "Doe"
      }

      command =
        Reset.new(%{
          id: aggregate.id
        })

      event = EnrichmentAggregate.execute(aggregate, command)

      assert %EnrichmentReset{} = event
      assert event.id == command.id
      assert event.timestamp == command.timestamp
    end
  end

  describe "alternate_names handling" do
    test "stores alternate_names from Trestle ProviderEnrichmentCompleted in aggregate state" do
      aggregate = %EnrichmentAggregate{
        id: Ecto.UUID.generate(),
        alternate_names: []
      }

      event = %ProviderEnrichmentCompleted{
        id: aggregate.id,
        phone: "5551234567",
        provider_type: "trestle",
        status: "success",
        enrichment_data: %{
          first_name: "John",
          last_name: "Smith",
          alternate_names: ["Johnny Smith", "J. Smith", "John Smyth"]
        },
        quality_metadata: %{},
        timestamp: NaiveDateTime.utc_now()
      }

      updated_aggregate = EnrichmentAggregate.apply(aggregate, event)

      assert updated_aggregate.alternate_names == ["Johnny Smith", "J. Smith", "John Smyth"]
    end

    test "preserves existing alternate_names for non-Trestle providers" do
      existing_names = ["Johnny Smith", "J. Smith"]

      aggregate = %EnrichmentAggregate{
        id: Ecto.UUID.generate(),
        alternate_names: existing_names
      }

      event = %ProviderEnrichmentCompleted{
        id: aggregate.id,
        phone: "5551234567",
        provider_type: "faraday",
        status: "success",
        enrichment_data: %{age: 30},
        quality_metadata: %{},
        timestamp: NaiveDateTime.utc_now()
      }

      updated_aggregate = EnrichmentAggregate.apply(aggregate, event)

      assert updated_aggregate.alternate_names == existing_names
    end

    test "handles missing alternate_names in Trestle data" do
      aggregate = %EnrichmentAggregate{
        id: Ecto.UUID.generate(),
        alternate_names: ["Old Name"]
      }

      event = %ProviderEnrichmentCompleted{
        id: aggregate.id,
        phone: "5551234567",
        provider_type: "trestle",
        status: "success",
        enrichment_data: %{
          first_name: "John",
          last_name: "Smith"
          # No alternate_names field
        },
        quality_metadata: %{},
        timestamp: NaiveDateTime.utc_now()
      }

      updated_aggregate = EnrichmentAggregate.apply(aggregate, event)

      assert updated_aggregate.alternate_names == []
    end

    test "includes alternate_names in EnrichmentComposed event from aggregate state" do
      alternate_names = ["Johnny Smith", "J. Smith"]

      aggregate = %EnrichmentAggregate{
        id: Ecto.UUID.generate(),
        phone: "5551234567",
        alternate_names: alternate_names
      }

      command =
        CompleteEnrichmentComposition.new(%{
          id: aggregate.id,
          composed_data: %{
            first_name: "John",
            last_name: "Smith",
            age: 30
          },
          data_sources: %{age: :faraday},
          provider_scores: %{faraday: 95}
        })

      event = EnrichmentAggregate.execute(aggregate, command)

      assert %EnrichmentComposed{} = event
      assert event.alternate_names == alternate_names
    end

    test "EnrichmentComposed works without alternate_names (backwards compatibility)" do
      aggregate = %EnrichmentAggregate{
        id: Ecto.UUID.generate(),
        phone: "5551234567"
        # No alternate_names field set
      }

      command =
        CompleteEnrichmentComposition.new(%{
          id: aggregate.id,
          composed_data: %{first_name: "John"},
          data_sources: %{},
          provider_scores: %{faraday: 95}
        })

      event = EnrichmentAggregate.execute(aggregate, command)

      assert %EnrichmentComposed{} = event
      assert event.alternate_names == []
    end
  end

  describe "apply/2 with EnrichmentReset" do
    test "resets aggregate state to initial values" do
      id = Ecto.UUID.generate()
      timestamp = NaiveDateTime.utc_now()

      aggregate = %EnrichmentAggregate{
        id: id,
        first_name: "John",
        last_name: "Doe",
        emails: ["john@example.com"],
        phone: "5551234567",
        addresses: [%{city: "Dallas", state: "TX"}],
        ptt: 85,
        last_provider_requested: "faraday",
        last_provider_succeeded: "endato",
        last_provider_failed: "trestle",
        provider_request_timestamp: ~N[2024-01-01 10:00:00],
        provider_success_timestamp: ~N[2024-01-01 11:00:00],
        provider_failure_timestamp: ~N[2024-01-01 12:00:00],
        last_composition_timestamp: ~N[2024-01-01 13:00:00],
        timestamp: ~N[2024-01-01 14:00:00]
      }

      event = %EnrichmentReset{
        id: id,
        timestamp: timestamp
      }

      updated_aggregate = EnrichmentAggregate.apply(aggregate, event)

      # Should reset all fields except id and timestamp
      assert updated_aggregate.id == id
      assert updated_aggregate.timestamp == timestamp
      assert updated_aggregate.first_name == nil
      assert updated_aggregate.last_name == nil
      assert updated_aggregate.emails == []
      assert updated_aggregate.phone == nil
      assert updated_aggregate.addresses == []
      assert updated_aggregate.ptt == 0
      assert updated_aggregate.last_provider_requested == nil
      assert updated_aggregate.last_provider_succeeded == nil
      assert updated_aggregate.last_provider_failed == nil
      assert updated_aggregate.provider_request_timestamp == nil
      assert updated_aggregate.provider_success_timestamp == nil
      assert updated_aggregate.provider_failure_timestamp == nil
      assert updated_aggregate.last_composition_timestamp == nil
    end
  end

  describe "execute/2 with Jitter" do
    test "Jittered event uses command ID not aggregate state ID" do
      # Reproduces bug where 262k+ aggregates had ptt but state.id == nil
      # (they were initialized with EnrichedWithFaraday which sets ptt but not id)
      # The Jittered event must use the command's ID, not state.id
      aggregate = %EnrichmentAggregate{
        id: nil,
        ptt: 65
      }

      command_id = Ecto.UUID.generate()

      command = %Jitter{
        id: command_id,
        timestamp: NaiveDateTime.utc_now()
      }

      event = EnrichmentAggregate.execute(aggregate, command)

      assert %Jittered{} = event
      assert event.id == command_id
    end
  end
end
