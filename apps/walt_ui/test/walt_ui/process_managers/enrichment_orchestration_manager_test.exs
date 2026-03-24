defmodule WaltUi.ProcessManagers.EnrichmentOrchestrationManagerTest do
  use WaltUi.CqrsCase

  alias CQRS.Enrichments.Commands.RequestEnrichmentComposition
  alias CQRS.Enrichments.Commands.RequestProviderEnrichment
  alias CQRS.Enrichments.Events.EnrichmentRequested
  alias CQRS.Enrichments.Events.ProviderEnrichmentCompleted
  alias CQRS.Enrichments.Events.ProviderEnrichmentRequested
  alias WaltUi.ProcessManagers.EnrichmentOrchestrationManager
  alias WaltUi.Projections.Trestle

  describe "interested?/1" do
    test "returns {:start, uuid} for EnrichmentRequested events" do
      event_id = Ecto.UUID.generate()

      event = %EnrichmentRequested{
        id: event_id,
        email: "john@example.com",
        first_name: "John",
        last_name: "Doe",
        phone: "1234567890",
        user_id: Ecto.UUID.generate(),
        timestamp: NaiveDateTime.utc_now()
      }

      assert {:continue, ^event_id} = EnrichmentOrchestrationManager.interested?(event)
    end

    test "returns {:continue, uuid} for successful trestle ProviderEnrichmentCompleted events" do
      event_id = Ecto.UUID.generate()

      event = %ProviderEnrichmentCompleted{
        id: event_id,
        phone: "5551234567",
        provider_type: "trestle",
        status: "success",
        enrichment_data: %{age_range: "25-34"},
        quality_metadata: %{},
        timestamp: NaiveDateTime.utc_now()
      }

      assert {:continue, ^event_id} = EnrichmentOrchestrationManager.interested?(event)
    end

    test "returns {:continue, uuid} for successful faraday ProviderEnrichmentCompleted events" do
      event_id = Ecto.UUID.generate()

      event = %ProviderEnrichmentCompleted{
        id: event_id,
        phone: "5551234567",
        provider_type: "faraday",
        status: "success",
        enrichment_data: %{age: 30},
        quality_metadata: %{},
        timestamp: NaiveDateTime.utc_now()
      }

      assert {:continue, ^event_id} = EnrichmentOrchestrationManager.interested?(event)
    end

    test "returns {:stop, uuid} for failed trestle ProviderEnrichmentCompleted events" do
      event_id = Ecto.UUID.generate()

      event = %ProviderEnrichmentCompleted{
        id: event_id,
        phone: "5551234567",
        provider_type: "trestle",
        status: "error",
        error_data: %{reason: "timeout"},
        quality_metadata: %{},
        timestamp: NaiveDateTime.utc_now()
      }

      assert {:stop, ^event_id} = EnrichmentOrchestrationManager.interested?(event)
    end

    test "returns {:continue, uuid} for failed faraday ProviderEnrichmentCompleted events" do
      event_id = Ecto.UUID.generate()

      event = %ProviderEnrichmentCompleted{
        id: event_id,
        phone: "5551234567",
        provider_type: "faraday",
        status: "error",
        error_data: %{reason: "timeout"},
        quality_metadata: %{},
        timestamp: NaiveDateTime.utc_now()
      }

      assert {:continue, ^event_id} = EnrichmentOrchestrationManager.interested?(event)
    end

    test "returns false for endato ProviderEnrichmentCompleted events" do
      event = %ProviderEnrichmentCompleted{
        id: Ecto.UUID.generate(),
        phone: "5551234567",
        provider_type: "endato",
        status: "success",
        enrichment_data: %{addresses: []},
        quality_metadata: %{},
        timestamp: NaiveDateTime.utc_now()
      }

      refute EnrichmentOrchestrationManager.interested?(event)
    end

    test "returns false for other events" do
      event = %ProviderEnrichmentRequested{
        id: Ecto.UUID.generate(),
        provider_type: "faraday",
        contact_data: %{},
        provider_config: %{},
        timestamp: NaiveDateTime.utc_now()
      }

      refute EnrichmentOrchestrationManager.interested?(event)
    end
  end

  describe "handle/2 with EnrichmentRequested" do
    test "returns command for trestle provider" do
      state = %EnrichmentOrchestrationManager{}

      event = %EnrichmentRequested{
        id: Ecto.UUID.generate(),
        email: "john@example.com",
        first_name: "John",
        last_name: "Doe",
        phone: "1234567890",
        user_id: Ecto.UUID.generate(),
        timestamp: NaiveDateTime.utc_now()
      }

      commands = EnrichmentOrchestrationManager.handle(state, event)

      assert length(commands) == 1

      trestle_command = List.first(commands)

      assert %RequestProviderEnrichment{} = trestle_command
      assert trestle_command.id == event.id
      assert trestle_command.provider_type == "trestle"

      assert trestle_command.contact_data == %{
               email: event.email,
               first_name: event.first_name,
               last_name: event.last_name,
               phone: event.phone,
               user_id: event.user_id
             }
    end
  end

  describe "handle/2 with ProviderEnrichmentCompleted for trestle success" do
    test "returns only faraday request command without composition" do
      state = %EnrichmentOrchestrationManager{}

      event = %ProviderEnrichmentCompleted{
        id: Ecto.UUID.generate(),
        phone: "5551234567",
        provider_type: "trestle",
        status: "success",
        enrichment_data: %{
          age_range: "25-34",
          addresses: [%{city: "Austin"}],
          phone: "5551234567"
        },
        quality_metadata: %{match_score: 0.95},
        timestamp: NaiveDateTime.utc_now()
      }

      commands = EnrichmentOrchestrationManager.handle(state, event)

      assert length(commands) == 1

      faraday_command = List.first(commands)

      assert %RequestProviderEnrichment{} = faraday_command
      assert faraday_command.id == event.id
      assert faraday_command.provider_type == "faraday"

      # Ensure no composition request is included
      refute Enum.any?(commands, &match?(%RequestEnrichmentComposition{}, &1))
    end

    test "skips faraday and requests composition directly when no addresses available" do
      state = %EnrichmentOrchestrationManager{}

      event = %ProviderEnrichmentCompleted{
        id: Ecto.UUID.generate(),
        phone: "5551234567",
        provider_type: "trestle",
        status: "success",
        enrichment_data: %{
          age_range: "25-34",
          addresses: [],
          phone: "5551234567",
          first_name: "John",
          last_name: "Doe"
        },
        quality_metadata: %{match_score: 0.95},
        timestamp: NaiveDateTime.utc_now()
      }

      commands = EnrichmentOrchestrationManager.handle(state, event)

      assert length(commands) == 1

      composition_command = List.first(commands)

      assert %RequestEnrichmentComposition{} = composition_command
      assert composition_command.id == event.id

      assert length(composition_command.provider_data) == 1
      trestle_data = List.first(composition_command.provider_data)
      assert trestle_data.provider_type == "trestle"
      assert trestle_data.status == "success"
      assert trestle_data.enrichment_data == event.enrichment_data
    end

    test "skips faraday when addresses field is missing from enrichment data" do
      state = %EnrichmentOrchestrationManager{}

      event = %ProviderEnrichmentCompleted{
        id: Ecto.UUID.generate(),
        phone: "5551234567",
        provider_type: "trestle",
        status: "success",
        enrichment_data: %{
          age_range: "25-34",
          phone: "5551234567",
          first_name: "John",
          last_name: "Doe"
        },
        quality_metadata: %{match_score: 0.95},
        timestamp: NaiveDateTime.utc_now()
      }

      commands = EnrichmentOrchestrationManager.handle(state, event)

      assert length(commands) == 1

      composition_command = List.first(commands)

      assert %RequestEnrichmentComposition{} = composition_command
      assert composition_command.id == event.id
    end
  end

  describe "handle/2 with ProviderEnrichmentCompleted for faraday completion" do
    test "returns composition request command when trestle data exists (faraday success)" do
      # Set up state with existing Trestle data
      state = %EnrichmentOrchestrationManager{
        id: Ecto.UUID.generate(),
        contact_data: %{
          email: "john@example.com",
          first_name: "John",
          last_name: "Doe",
          phone: "1234567890"
        },
        provider_data: %{
          "trestle" => %{
            enrichment_data: %{age_range: "25-34", first_name: "John", last_name: "Doe"},
            quality_metadata: %{match_count: 1}
          }
        }
      }

      event = %ProviderEnrichmentCompleted{
        id: state.id,
        phone: "5551234567",
        provider_type: "faraday",
        status: "success",
        enrichment_data: %{age: 30, income: 75_000, phone: "5551234567"},
        quality_metadata: %{match_type: "address_full_name"},
        timestamp: NaiveDateTime.utc_now()
      }

      commands = EnrichmentOrchestrationManager.handle(state, event)

      assert length(commands) == 1

      composition_command = List.first(commands)
      assert %RequestEnrichmentComposition{} = composition_command
      assert composition_command.id == event.id
    end

    test "returns no commands when trestle data is missing (faraday success)" do
      # State without Trestle data
      state = %EnrichmentOrchestrationManager{
        id: Ecto.UUID.generate(),
        contact_data: %{
          email: "john@example.com",
          first_name: "John",
          last_name: "Doe",
          phone: "1234567890"
        },
        provider_data: %{}
      }

      event = %ProviderEnrichmentCompleted{
        id: state.id,
        phone: "5551234567",
        provider_type: "faraday",
        status: "success",
        enrichment_data: %{age: 30, income: 75_000, phone: "5551234567"},
        quality_metadata: %{match_type: "address_full_name"},
        timestamp: NaiveDateTime.utc_now()
      }

      commands = EnrichmentOrchestrationManager.handle(state, event)

      assert commands == []
    end

    test "returns composition request command when trestle data exists (faraday failure)" do
      # Set up state with existing Trestle data
      state = %EnrichmentOrchestrationManager{
        id: Ecto.UUID.generate(),
        contact_data: %{
          email: "john@example.com",
          first_name: "John",
          last_name: "Doe",
          phone: "1234567890"
        },
        provider_data: %{
          "trestle" => %{
            enrichment_data: %{age_range: "25-34", first_name: "John", last_name: "Doe"},
            quality_metadata: %{match_count: 1}
          }
        }
      }

      event = %ProviderEnrichmentCompleted{
        id: state.id,
        phone: "5551234567",
        provider_type: "faraday",
        status: "error",
        error_data: %{reason: "timeout"},
        quality_metadata: %{},
        timestamp: NaiveDateTime.utc_now()
      }

      commands = EnrichmentOrchestrationManager.handle(state, event)

      assert length(commands) == 1

      composition_command = List.first(commands)
      assert %RequestEnrichmentComposition{} = composition_command
      assert composition_command.id == event.id

      # The composition should only include Trestle data (no failed Faraday data)
      provider_data = composition_command.provider_data
      assert length(provider_data) == 1

      # Should have Trestle data only
      trestle_data = Enum.find(provider_data, &(&1.provider_type == "trestle"))
      assert trestle_data != nil
      assert trestle_data.enrichment_data.age_range == "25-34"

      # Should NOT have Faraday data (since it failed)
      faraday_data = Enum.find(provider_data, &(&1.provider_type == "faraday"))
      assert faraday_data == nil
    end

    test "returns no commands when trestle data is missing (faraday failure)" do
      # State without Trestle data
      state = %EnrichmentOrchestrationManager{
        id: Ecto.UUID.generate(),
        contact_data: %{
          email: "john@example.com",
          first_name: "John",
          last_name: "Doe",
          phone: "1234567890"
        },
        provider_data: %{}
      }

      event = %ProviderEnrichmentCompleted{
        id: state.id,
        phone: "5551234567",
        provider_type: "faraday",
        status: "error",
        error_data: %{reason: "timeout"},
        quality_metadata: %{},
        timestamp: NaiveDateTime.utc_now()
      }

      commands = EnrichmentOrchestrationManager.handle(state, event)

      assert commands == []
    end

    test "includes both trestle and faraday data in final composition" do
      # Set up state with existing Trestle data
      state = %EnrichmentOrchestrationManager{
        id: Ecto.UUID.generate(),
        contact_data: %{
          email: "john@example.com",
          first_name: "John",
          last_name: "Doe",
          phone: "1234567890"
        },
        provider_data: %{
          "trestle" => %{
            enrichment_data: %{age_range: "25-34", first_name: "John", last_name: "Doe"},
            quality_metadata: %{match_count: 1}
          }
        }
      }

      # Faraday completion event
      faraday_event = %ProviderEnrichmentCompleted{
        id: Ecto.UUID.generate(),
        phone: "5551234567",
        provider_type: "faraday",
        status: "success",
        enrichment_data: %{age: 35, household_income: 75_000, phone: "5551234567"},
        quality_metadata: %{match_type: "address_full_name"},
        timestamp: NaiveDateTime.utc_now()
      }

      commands = EnrichmentOrchestrationManager.handle(state, faraday_event)

      assert length(commands) == 1
      composition_command = List.first(commands)
      assert %RequestEnrichmentComposition{} = composition_command

      # The composition should include both providers' data
      provider_data = composition_command.provider_data
      assert length(provider_data) == 2

      # Should have Trestle data
      trestle_data = Enum.find(provider_data, &(&1.provider_type == "trestle"))
      assert trestle_data != nil
      assert trestle_data.enrichment_data.age_range == "25-34"

      # Should have Faraday data
      faraday_data = Enum.find(provider_data, &(&1.provider_type == "faraday"))
      assert faraday_data != nil
      assert faraday_data.enrichment_data.age == 35
      assert faraday_data.enrichment_data.household_income == 75_000
    end
  end

  describe "apply/2" do
    test "initializes state for EnrichmentRequested events" do
      event = %EnrichmentRequested{
        id: Ecto.UUID.generate(),
        email: "john@example.com",
        first_name: "John",
        last_name: "Doe",
        phone: "1234567890",
        user_id: Ecto.UUID.generate(),
        timestamp: NaiveDateTime.utc_now()
      }

      state = EnrichmentOrchestrationManager.apply(nil, event)

      assert state.id == event.id

      assert state.contact_data == %{
               email: event.email,
               first_name: event.first_name,
               last_name: event.last_name,
               phone: event.phone,
               user_id: event.user_id
             }

      assert state.provider_data == %{}
      assert state.provider_config == %{}
    end

    test "stores provider data and updates contact data for successful trestle completion" do
      event_id = Ecto.UUID.generate()

      initial_state = %EnrichmentOrchestrationManager{
        id: event_id,
        contact_data: %{
          email: "john@example.com",
          first_name: "John",
          last_name: nil,
          phone: "1234567890"
        },
        provider_data: %{},
        provider_config: %{}
      }

      event = %ProviderEnrichmentCompleted{
        id: event_id,
        phone: "5551234567",
        provider_type: "trestle",
        status: "success",
        enrichment_data: %{
          age_range: "25-34",
          addresses: [%{city: "Austin"}],
          first_name: "John",
          last_name: "Doe"
        },
        quality_metadata: %{match_score: 0.95},
        timestamp: NaiveDateTime.utc_now()
      }

      updated_state = EnrichmentOrchestrationManager.apply(initial_state, event)

      assert updated_state.id == event_id

      assert updated_state.contact_data == %{
               email: "john@example.com",
               first_name: "John",
               last_name: "Doe",
               phone: "1234567890",
               addresses: [%{city: "Austin"}]
             }

      assert updated_state.provider_data["trestle"] == %{
               enrichment_data: event.enrichment_data,
               quality_metadata: event.quality_metadata
             }

      # Provider config would be set from a different event/command
      assert updated_state.provider_config == initial_state.provider_config
    end

    test "updates multiple contact fields from trestle enrichment data" do
      event_id = Ecto.UUID.generate()

      initial_state = %EnrichmentOrchestrationManager{
        id: event_id,
        contact_data: %{email: nil, first_name: "J", last_name: nil, phone: "1234567890"},
        provider_data: %{},
        provider_config: %{}
      }

      event = %ProviderEnrichmentCompleted{
        id: event_id,
        phone: "5551234567",
        provider_type: "trestle",
        status: "success",
        enrichment_data: %{
          age_range: "25-34",
          addresses: [%{city: "Austin"}],
          first_name: "John",
          last_name: "Doe",
          emails: ["john.doe@example.com", "johndoe@gmail.com"]
        },
        quality_metadata: %{match_score: 0.95},
        timestamp: NaiveDateTime.utc_now()
      }

      updated_state = EnrichmentOrchestrationManager.apply(initial_state, event)

      assert updated_state.id == event_id

      assert updated_state.contact_data == %{
               # Uses first email from Trestle
               email: "john.doe@example.com",
               first_name: "John",
               last_name: "Doe",
               phone: "1234567890",
               addresses: [%{city: "Austin"}]
             }

      assert updated_state.provider_data["trestle"] == %{
               enrichment_data: event.enrichment_data,
               quality_metadata: event.quality_metadata
             }
    end

    test "does not update email if one already exists" do
      event_id = Ecto.UUID.generate()

      initial_state = %EnrichmentOrchestrationManager{
        id: event_id,
        contact_data: %{
          email: "existing@example.com",
          first_name: "John",
          last_name: nil,
          phone: "1234567890"
        },
        provider_data: %{},
        provider_config: %{}
      }

      event = %ProviderEnrichmentCompleted{
        id: event_id,
        phone: "5551234567",
        provider_type: "trestle",
        status: "success",
        enrichment_data: %{
          first_name: "John",
          last_name: "Doe",
          emails: ["new.email@example.com", "another@gmail.com"]
        },
        quality_metadata: %{match_score: 0.95},
        timestamp: NaiveDateTime.utc_now()
      }

      updated_state = EnrichmentOrchestrationManager.apply(initial_state, event)

      assert updated_state.id == event_id
      # Email should NOT be updated
      assert updated_state.contact_data.email == "existing@example.com"
      # But other fields should be updated
      assert updated_state.contact_data.last_name == "Doe"
      assert updated_state.contact_data.first_name == "John"
      assert updated_state.contact_data.phone == "1234567890"
    end

    test "handles empty emails array from trestle" do
      initial_state = %EnrichmentOrchestrationManager{
        id: Ecto.UUID.generate(),
        contact_data: %{email: nil, first_name: "John", last_name: nil, phone: "1234567890"},
        provider_data: %{},
        provider_config: %{}
      }

      event = %ProviderEnrichmentCompleted{
        id: Ecto.UUID.generate(),
        phone: "5551234567",
        provider_type: "trestle",
        status: "success",
        enrichment_data: %{
          first_name: "John",
          last_name: "Doe",
          emails: []
        },
        quality_metadata: %{match_score: 0.95},
        timestamp: NaiveDateTime.utc_now()
      }

      updated_state = EnrichmentOrchestrationManager.apply(initial_state, event)

      # Email should remain nil when emails array is empty
      assert updated_state.contact_data.email == nil
      assert updated_state.contact_data.last_name == "Doe"
    end

    test "stores provider data for successful faraday completion" do
      event_id = Ecto.UUID.generate()

      initial_state = %EnrichmentOrchestrationManager{
        id: event_id,
        contact_data: %{
          email: "john@example.com",
          first_name: "John",
          last_name: "Doe",
          phone: "1234567890"
        },
        provider_data: %{
          "trestle" => %{
            enrichment_data: %{age_range: "25-34"},
            quality_metadata: %{match_score: 0.95}
          }
        },
        provider_config: %{faraday: %{use_addresses: true}}
      }

      event = %ProviderEnrichmentCompleted{
        id: event_id,
        phone: "5551234567",
        provider_type: "faraday",
        status: "success",
        enrichment_data: %{age: 30, income: 75_000},
        quality_metadata: %{match_type: "address_full_name"},
        timestamp: NaiveDateTime.utc_now()
      }

      updated_state = EnrichmentOrchestrationManager.apply(initial_state, event)

      assert updated_state.id == event_id
      assert updated_state.contact_data == initial_state.contact_data

      assert updated_state.provider_data["faraday"] == %{
               enrichment_data: event.enrichment_data,
               quality_metadata: event.quality_metadata
             }

      assert updated_state.provider_data["trestle"] == initial_state.provider_data["trestle"]
      assert updated_state.provider_config == initial_state.provider_config
    end

    test "does not store provider data for failed faraday completion" do
      event_id = Ecto.UUID.generate()

      initial_state = %EnrichmentOrchestrationManager{
        id: event_id,
        contact_data: %{
          email: "john@example.com",
          first_name: "John",
          last_name: "Doe",
          phone: "1234567890"
        },
        provider_data: %{
          "trestle" => %{
            enrichment_data: %{age_range: "25-34"},
            quality_metadata: %{match_score: 0.95}
          }
        },
        provider_config: %{faraday: %{use_addresses: true}}
      }

      event = %ProviderEnrichmentCompleted{
        id: event_id,
        phone: "5551234567",
        provider_type: "faraday",
        status: "error",
        error_data: %{reason: "timeout"},
        quality_metadata: %{},
        timestamp: NaiveDateTime.utc_now()
      }

      updated_state = EnrichmentOrchestrationManager.apply(initial_state, event)

      assert updated_state.id == event_id
      assert updated_state.contact_data == initial_state.contact_data

      # Faraday data should NOT be stored since it failed
      refute Map.has_key?(updated_state.provider_data, "faraday")

      # Trestle data should remain unchanged
      assert updated_state.provider_data["trestle"] == initial_state.provider_data["trestle"]
      assert updated_state.provider_config == initial_state.provider_config
    end
  end

  describe "after_command/2" do
    test "returns :stop after RequestEnrichmentComposition with both trestle and faraday data" do
      state = %EnrichmentOrchestrationManager{
        id: Ecto.UUID.generate(),
        provider_data: %{
          "trestle" => %{enrichment_data: %{age_range: "25-34"}},
          "faraday" => %{enrichment_data: %{age: 30}}
        }
      }

      command =
        RequestEnrichmentComposition.new(%{
          id: state.id,
          provider_data: [
            %{provider_type: "trestle", enrichment_data: %{age_range: "25-34"}},
            %{provider_type: "faraday", enrichment_data: %{age: 30}}
          ],
          composition_rules: :default
        })

      assert :stop = EnrichmentOrchestrationManager.after_command(state, command)
    end

    test "returns :continue after RequestEnrichmentComposition with only trestle data" do
      state = %EnrichmentOrchestrationManager{
        id: Ecto.UUID.generate(),
        provider_data: %{
          "trestle" => %{enrichment_data: %{age_range: "25-34"}}
        }
      }

      command =
        RequestEnrichmentComposition.new(%{
          id: state.id,
          provider_data: [
            %{provider_type: "trestle", enrichment_data: %{age_range: "25-34"}}
          ],
          composition_rules: :default
        })

      assert :continue = EnrichmentOrchestrationManager.after_command(state, command)
    end

    test "returns :continue after other commands" do
      state = %EnrichmentOrchestrationManager{id: Ecto.UUID.generate()}

      command =
        RequestProviderEnrichment.new(%{
          id: state.id,
          provider_type: "trestle",
          contact_data: %{email: "test@example.com"}
        })

      assert :continue = EnrichmentOrchestrationManager.after_command(state, command)
    end
  end

  describe "state recovery mechanism" do
    test "recovers Trestle data with addresses when state is missing but projection exists" do
      enrichment_id = Ecto.UUID.generate()

      # Create Trestle projection with addresses
      trestle_projection = %Trestle{
        id: enrichment_id,
        phone: "5551234567",
        first_name: "John",
        last_name: "Doe",
        emails: ["john@example.com"],
        alternate_names: ["Johnny"],
        age_range: "30-39",
        addresses: [%{street_1: "123 Main St", city: "Austin", state: "TX", zip: "78701"}],
        quality_metadata: %{match_score: 0.95, sources: ["public_records"]}
      }

      {:ok, _} = Repo.insert(trestle_projection)

      # State without Trestle data (simulating process restart)
      state = %EnrichmentOrchestrationManager{
        id: enrichment_id,
        contact_data: %{email: "john@example.com", phone: "5551234567"},
        # No Trestle data in memory
        provider_data: %{}
      }

      # Faraday completion event
      faraday_event = %ProviderEnrichmentCompleted{
        id: enrichment_id,
        phone: "5551234567",
        provider_type: "faraday",
        status: "success",
        enrichment_data: %{age: 35, income: 75_000},
        quality_metadata: %{match_type: "full_address_name"},
        timestamp: NaiveDateTime.utc_now()
      }

      # Should recover Trestle data and proceed with composition
      commands = EnrichmentOrchestrationManager.handle(state, faraday_event)

      assert length(commands) == 1
      composition_command = List.first(commands)
      assert %RequestEnrichmentComposition{} = composition_command

      # Verify recovered Trestle data includes addresses
      provider_data = composition_command.provider_data
      assert length(provider_data) == 2

      trestle_data = Enum.find(provider_data, &(&1.provider_type == "trestle"))
      assert trestle_data != nil
      assert trestle_data.enrichment_data.first_name == "John"
      assert trestle_data.enrichment_data.last_name == "Doe"

      assert trestle_data.enrichment_data.addresses == [
               %{street_1: "123 Main St", city: "Austin", state: "TX", zip: "78701"}
             ]

      assert trestle_data.quality_metadata == %{
               "match_score" => 0.95,
               "sources" => ["public_records"]
             }

      # Verify Faraday data is also included
      faraday_data = Enum.find(provider_data, &(&1.provider_type == "faraday"))
      assert faraday_data != nil
      assert faraday_data.enrichment_data.age == 35
      assert faraday_data.enrichment_data.income == 75_000
    end

    test "recovers both Trestle and Endato data when both projections exist" do
      enrichment_id = Ecto.UUID.generate()

      # Create both Trestle and Endato projections
      trestle_projection = %Trestle{
        id: enrichment_id,
        phone: "5551234567",
        first_name: "Jane",
        last_name: "Smith",
        emails: ["jane@example.com"],
        age_range: "25-34",
        addresses: [%{street_1: "456 Oak Ave", city: "Dallas", state: "TX", zip: "75201"}],
        quality_metadata: %{match_score: 0.88}
      }

      endato_projection = %WaltUi.Projections.Endato{
        id: enrichment_id,
        phone: "5551234567",
        first_name: "Jane",
        last_name: "Smith",
        emails: ["jane.smith@gmail.com"],
        addresses: [%{street_1: "456 Oak Ave", city: "Dallas", state: "TX", zip: "75201"}],
        quality_metadata: %{confidence: "high", source: "proprietary"}
      }

      {:ok, _} = Repo.insert(trestle_projection)
      {:ok, _} = Repo.insert(endato_projection)

      # State without any provider data
      state = %EnrichmentOrchestrationManager{
        id: enrichment_id,
        contact_data: %{email: "jane@example.com", phone: "5551234567"},
        provider_data: %{}
      }

      # Faraday completion event
      faraday_event = %ProviderEnrichmentCompleted{
        id: enrichment_id,
        phone: "5551234567",
        provider_type: "faraday",
        status: "success",
        enrichment_data: %{age: 28, household_income: 65_000},
        quality_metadata: %{match_type: "address_name"},
        timestamp: NaiveDateTime.utc_now()
      }

      commands = EnrichmentOrchestrationManager.handle(state, faraday_event)

      assert length(commands) == 1
      composition_command = List.first(commands)
      provider_data = composition_command.provider_data
      # Trestle, Endato, and Faraday
      assert length(provider_data) == 3

      # Verify all provider data is present with correct quality_metadata
      trestle_data = Enum.find(provider_data, &(&1.provider_type == "trestle"))
      assert trestle_data.quality_metadata == %{"match_score" => 0.88}

      endato_data = Enum.find(provider_data, &(&1.provider_type == "endato"))
      assert endato_data.quality_metadata == %{"confidence" => "high", "source" => "proprietary"}

      faraday_data = Enum.find(provider_data, &(&1.provider_type == "faraday"))
      assert faraday_data.quality_metadata == %{match_type: "address_name"}
    end

    test "gracefully handles missing Trestle projection by skipping composition" do
      enrichment_id = Ecto.UUID.generate()

      # No projections exist

      # State without Trestle data
      state = %EnrichmentOrchestrationManager{
        id: enrichment_id,
        contact_data: %{email: "test@example.com", phone: "5551234567"},
        provider_data: %{}
      }

      # Faraday completion event
      faraday_event = %ProviderEnrichmentCompleted{
        id: enrichment_id,
        phone: "5551234567",
        provider_type: "faraday",
        status: "success",
        enrichment_data: %{age: 30},
        quality_metadata: %{match_type: "phone_only"},
        timestamp: NaiveDateTime.utc_now()
      }

      # Should return no commands (skip composition)
      commands = EnrichmentOrchestrationManager.handle(state, faraday_event)
      assert commands == []
    end

    test "uses state data when available instead of recovery" do
      enrichment_id = Ecto.UUID.generate()

      # Create projection that should NOT be used
      trestle_projection = %Trestle{
        id: enrichment_id,
        phone: "5551234567",
        first_name: "WrongName",
        last_name: "FromProjection",
        emails: ["wrong@example.com"],
        quality_metadata: %{should_not_be_used: true}
      }

      {:ok, _} = Repo.insert(trestle_projection)

      # State WITH Trestle data (normal case)
      state = %EnrichmentOrchestrationManager{
        id: enrichment_id,
        contact_data: %{email: "correct@example.com", phone: "5551234567"},
        provider_data: %{
          "trestle" => %{
            enrichment_data: %{first_name: "CorrectName", last_name: "FromState"},
            quality_metadata: %{from_state: true}
          }
        }
      }

      # Faraday completion event
      faraday_event = %ProviderEnrichmentCompleted{
        id: enrichment_id,
        phone: "5551234567",
        provider_type: "faraday",
        status: "success",
        enrichment_data: %{age: 25},
        quality_metadata: %{match_type: "full_match"},
        timestamp: NaiveDateTime.utc_now()
      }

      commands = EnrichmentOrchestrationManager.handle(state, faraday_event)

      assert length(commands) == 1
      composition_command = List.first(commands)
      provider_data = composition_command.provider_data

      # Should use state data, not projection data
      trestle_data = Enum.find(provider_data, &(&1.provider_type == "trestle"))
      assert trestle_data.enrichment_data.first_name == "CorrectName"
      assert trestle_data.enrichment_data.last_name == "FromState"
      assert trestle_data.quality_metadata == %{from_state: true}
    end
  end

  describe "address conversion handling" do
    test "handles addresses with different key formats during state recovery" do
      enrichment_id = Ecto.UUID.generate()

      # Create a Trestle projection with addresses in different formats
      trestle_projection = %Trestle{
        id: enrichment_id,
        phone: "5551234567",
        first_name: "John",
        last_name: "Doe",
        addresses: [
          %Trestle.Address{
            street_1: "123 Main St",
            city: "New York",
            state: "NY",
            zip: "10001"
          }
        ],
        quality_metadata: %{confidence: 0.9}
      }

      Repo.insert!(trestle_projection)

      # Simulate state with no Trestle data (forcing recovery from projections)
      state = %EnrichmentOrchestrationManager{
        id: enrichment_id,
        provider_data: %{},
        contact_data: %{
          email: "john@example.com",
          first_name: "John",
          last_name: "Doe",
          phone: "5551234567",
          user_id: Ecto.UUID.generate()
        }
      }

      # Handle a Faraday completion that triggers composition with recovered data
      faraday_event = %ProviderEnrichmentCompleted{
        id: enrichment_id,
        phone: "5551234567",
        provider_type: "faraday",
        status: "success",
        enrichment_data: %{age: 35},
        quality_metadata: %{},
        timestamp: NaiveDateTime.utc_now()
      }

      commands = EnrichmentOrchestrationManager.handle(state, faraday_event)

      assert length(commands) == 1
      composition_command = List.first(commands)
      assert %RequestEnrichmentComposition{} = composition_command

      # Verify Trestle data was recovered and addresses were converted properly
      trestle_data =
        Enum.find(composition_command.provider_data, &(&1.provider_type == "trestle"))

      assert trestle_data != nil
      assert trestle_data.enrichment_data.first_name == "John"
      assert trestle_data.enrichment_data.last_name == "Doe"

      # Check that addresses were properly converted
      assert is_list(trestle_data.enrichment_data.addresses)
      assert length(trestle_data.enrichment_data.addresses) == 1

      address = List.first(trestle_data.enrichment_data.addresses)
      assert address.street_1 == "123 Main St"
      assert address.city == "New York"
      assert address.state == "NY"
      assert address.zip == "10001"
    end

    test "handles addresses as maps with string keys during recovery" do
      enrichment_id = Ecto.UUID.generate()

      # Insert using changeset which simulates how data might be stored
      # with addresses that could have string keys in older events
      attrs = %{
        id: enrichment_id,
        phone: "5551234567",
        first_name: "Jane",
        last_name: "Smith",
        addresses: [
          %{
            "street_1" => "456 Oak Ave",
            "city" => "Los Angeles",
            "state" => "CA",
            "zip" => "90001"
          }
        ],
        quality_metadata: %{confidence: 0.8}
      }

      %Trestle{}
      |> Trestle.changeset(attrs)
      |> Repo.insert!()

      # Simulate state recovery
      state = %EnrichmentOrchestrationManager{
        id: enrichment_id,
        provider_data: %{},
        contact_data: %{
          email: "jane@example.com",
          first_name: "Jane",
          last_name: "Smith",
          phone: "5551234567",
          user_id: Ecto.UUID.generate()
        }
      }

      faraday_event = %ProviderEnrichmentCompleted{
        id: enrichment_id,
        phone: "5551234567",
        provider_type: "faraday",
        status: "success",
        enrichment_data: %{age: 30},
        quality_metadata: %{},
        timestamp: NaiveDateTime.utc_now()
      }

      # This should not crash even with string-keyed addresses
      commands = EnrichmentOrchestrationManager.handle(state, faraday_event)

      assert length(commands) == 1
      composition_command = List.first(commands)
      assert %RequestEnrichmentComposition{} = composition_command

      trestle_data =
        Enum.find(composition_command.provider_data, &(&1.provider_type == "trestle"))

      assert trestle_data != nil
      assert is_list(trestle_data.enrichment_data.addresses)
    end
  end
end
