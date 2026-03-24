defmodule WaltUi.Projectors.PossibleAddressTest do
  use WaltUi.CqrsCase

  import AssertAsync
  import WaltUi.Factory

  alias CQRS.Enrichments.Events.EnrichedWithEndato
  alias CQRS.Enrichments.Events.EnrichedWithTrestle
  alias CQRS.Enrichments.Events.ProviderEnrichmentCompleted
  alias WaltUi.Projections.PossibleAddress

  describe "EnrichedWithEndato event" do
    test "ignores events with no addresses" do
      :endato
      |> params_for(addresses: [])
      |> then(&struct(EnrichedWithEndato, &1))
      |> append_event()

      assert [] = Repo.all(PossibleAddress)
    end

    test "projects new possible addresses" do
      :endato
      |> params_for()
      |> then(&struct(EnrichedWithEndato, &1))
      |> append_event()

      assert_async do
        assert [_one] = Repo.all(PossibleAddress)
      end
    end

    test "ignores existing possible addresses" do
      attrs = params_for(:possible_address)
      id = WaltUi.Projectors.PossibleAddress.to_id(attrs.enrichment_id, attrs)
      addr_1 = insert(:possible_address, Map.put(attrs, :id, id))
      [addr_2] = params_for(:endato).addresses

      :endato
      |> params_for(
        addresses: [
          %{
            street_1: addr_1.street_1,
            street_2: addr_1.street_2,
            city: addr_1.city,
            state: addr_1.state,
            zip: addr_1.zip
          },
          addr_2
        ]
      )
      |> Map.merge(%{id: addr_1.enrichment_id})
      |> then(&struct(EnrichedWithEndato, &1))
      |> append_event()

      assert_async do
        assert [_one, _two] = Repo.all(PossibleAddress)
      end
    end

    test "filters out addresses with invalid required fields for Endato" do
      append_event(%EnrichedWithEndato{
        id: Ecto.UUID.generate(),
        addresses: [
          # Valid address
          %{
            street_1: "123 Main St",
            street_2: "Unit 3",
            city: "Fooville",
            state: "OH",
            zip: "46862"
          },
          # Invalid: empty city
          %{
            street_1: "456 Oak Ave",
            street_2: nil,
            city: "",
            state: "OH",
            zip: "46863"
          },
          # Invalid: nil state
          %{
            street_1: "789 Pine St",
            street_2: nil,
            city: "Barville",
            state: nil,
            zip: "46864"
          },
          # Invalid: whitespace-only zip
          %{
            street_1: "101 Elm St",
            street_2: nil,
            city: "Bazville",
            state: "OH",
            zip: "   "
          },
          # Another valid address
          %{
            street_1: "202 Cedar Ave",
            street_2: "Apt 2",
            city: "Quxville",
            state: "OH",
            zip: "46865"
          }
        ],
        emails: ["foo@bar.com"],
        first_name: "Foo",
        last_name: "Bar",
        phone: "5551231234",
        timestamp: NaiveDateTime.utc_now()
      })

      assert_async do
        addresses = Repo.all(PossibleAddress)
        # Only the 2 valid addresses should be projected
        assert length(addresses) == 2

        street_names = Enum.map(addresses, & &1.street_1)
        assert "123 Main St" in street_names
        assert "202 Cedar Ave" in street_names

        # Invalid addresses should not be present
        refute "456 Oak Ave" in street_names
        refute "789 Pine St" in street_names
        refute "101 Elm St" in street_names
      end
    end
  end

  describe "EnrichedWithTrestle event" do
    test "projects new possible addresses from trestle data" do
      append_event(%EnrichedWithTrestle{
        id: Ecto.UUID.generate(),
        addresses: [
          %{
            street_1: "123 Main St",
            street_2: "Unit 3",
            city: "Fooville",
            state: "OH",
            zip: "46862"
          }
        ],
        age_range: "35-44",
        emails: ["foo@bar.com"],
        first_name: "Foo",
        last_name: "Bar",
        phone: "5551231234",
        timestamp: NaiveDateTime.utc_now()
      })

      assert_async do
        assert [
                 %{
                   street_1: "123 Main St",
                   street_2: "Unit 3",
                   city: "Fooville",
                   state: "OH",
                   zip: "46862"
                 }
               ] = Repo.all(PossibleAddress)
      end
    end

    test "trestle address cannot be overwritten by endato event with same address" do
      # Use the same enrichment ID for both events
      enrichment_id = Ecto.UUID.generate()

      # First, create a Trestle address
      append_event(%EnrichedWithTrestle{
        id: enrichment_id,
        addresses: [
          %{
            street_1: "123 Main St",
            street_2: "Unit 3",
            city: "Fooville",
            state: "OH",
            zip: "46862"
          }
        ],
        age_range: "35-44",
        emails: ["foo@bar.com"],
        first_name: "Foo",
        last_name: "Bar",
        phone: "5551231234",
        timestamp: NaiveDateTime.utc_now()
      })

      # Wait for the Trestle address to be projected
      assert_async do
        assert [%{enrichment_id: ^enrichment_id}] = Repo.all(PossibleAddress)
      end

      # Now try to create an Endato event with the same ID and same address
      append_event(%EnrichedWithEndato{
        id: enrichment_id,
        addresses: [
          %{
            street_1: "123 Main St",
            street_2: "Unit 3",
            city: "Fooville",
            state: "OH",
            zip: "46862"
          }
        ],
        emails: ["different@email.com"],
        first_name: "Different",
        last_name: "Person",
        phone: "5559876543",
        timestamp: NaiveDateTime.utc_now()
      })

      # Verify only one address exists and it's still from the original enrichment
      assert_async do
        addresses = Repo.all(PossibleAddress)
        assert length(addresses) == 1
        assert [%{enrichment_id: ^enrichment_id}] = addresses
      end
    end

    test "filters out addresses with invalid required fields" do
      append_event(%EnrichedWithTrestle{
        id: Ecto.UUID.generate(),
        addresses: [
          # Valid address
          %{
            street_1: "123 Main St",
            street_2: "Unit 3",
            city: "Fooville",
            state: "OH",
            zip: "46862"
          },
          # Invalid: empty city
          %{
            street_1: "456 Oak Ave",
            street_2: nil,
            city: "",
            state: "OH",
            zip: "46863"
          },
          # Invalid: nil state
          %{
            street_1: "789 Pine St",
            street_2: nil,
            city: "Barville",
            state: nil,
            zip: "46864"
          },
          # Invalid: whitespace-only zip
          %{
            street_1: "101 Elm St",
            street_2: nil,
            city: "Bazville",
            state: "OH",
            zip: "   "
          },
          # Another valid address
          %{
            street_1: "202 Cedar Ave",
            street_2: "Apt 2",
            city: "Quxville",
            state: "OH",
            zip: "46865"
          }
        ],
        age_range: "35-44",
        emails: ["foo@bar.com"],
        first_name: "Foo",
        last_name: "Bar",
        phone: "5551231234",
        timestamp: NaiveDateTime.utc_now()
      })

      assert_async do
        addresses = Repo.all(PossibleAddress)
        # Only the 2 valid addresses should be projected
        assert length(addresses) == 2

        street_names = Enum.map(addresses, & &1.street_1)
        assert "123 Main St" in street_names
        assert "202 Cedar Ave" in street_names

        # Invalid addresses should not be present
        refute "456 Oak Ave" in street_names
        refute "789 Pine St" in street_names
        refute "101 Elm St" in street_names
      end
    end
  end

  describe "ProviderEnrichmentCompleted event with endato or trestle provider" do
    test "projects new possible addresses from endato provider" do
      event_id = Ecto.UUID.generate()

      endato_data = %{
        addresses: [
          %{
            street_1: "123 Main St",
            street_2: "Unit 3",
            city: "Fooville",
            state: "OH",
            zip: "46862"
          }
        ],
        emails: ["foo@bar.com"],
        first_name: "John",
        last_name: "Doe",
        phone: "5551231234"
      }

      event = %ProviderEnrichmentCompleted{
        id: event_id,
        phone: "5551234567",
        provider_type: "endato",
        status: "success",
        enrichment_data: endato_data,
        timestamp: NaiveDateTime.utc_now()
      }

      append_event(event)

      assert_async do
        assert [%{street_1: "123 Main St", enrichment_id: ^event_id}] = Repo.all(PossibleAddress)
      end
    end

    test "projects new possible addresses from trestle provider" do
      event_id = Ecto.UUID.generate()

      trestle_data = %{
        addresses: [
          %{
            street_1: "456 Oak Ave",
            street_2: nil,
            city: "Barville",
            state: "CA",
            zip: "90210"
          }
        ],
        age_range: "35-44",
        emails: ["bar@example.com"],
        first_name: "Jane",
        last_name: "Smith",
        phone: "5559876543"
      }

      event = %ProviderEnrichmentCompleted{
        id: event_id,
        phone: "5551234567",
        provider_type: "trestle",
        status: "success",
        enrichment_data: trestle_data,
        timestamp: NaiveDateTime.utc_now()
      }

      append_event(event)

      assert_async do
        assert [%{street_1: "456 Oak Ave", enrichment_id: ^event_id}] = Repo.all(PossibleAddress)
      end
    end

    test "filters invalid addresses for both trestle and endato providers" do
      event_id = Ecto.UUID.generate()

      trestle_data = %{
        addresses: [
          # Valid address
          %{
            street_1: "123 Main St",
            street_2: "Unit 3",
            city: "Fooville",
            state: "OH",
            zip: "46862"
          },
          # Invalid: empty city (should be filtered for Trestle)
          %{
            street_1: "456 Oak Ave",
            street_2: nil,
            city: "",
            state: "OH",
            zip: "46863"
          }
        ],
        age_range: "35-44"
      }

      event = %ProviderEnrichmentCompleted{
        id: event_id,
        phone: "5551234567",
        provider_type: "trestle",
        status: "success",
        enrichment_data: trestle_data,
        timestamp: NaiveDateTime.utc_now()
      }

      append_event(event)

      assert_async do
        addresses = Repo.all(PossibleAddress)
        # Only the valid address should be projected for Trestle
        assert length(addresses) == 1
        assert [%{street_1: "123 Main St"}] = addresses
      end
    end

    test "ignores non-endato and non-trestle provider events" do
      event_id = Ecto.UUID.generate()

      event = %ProviderEnrichmentCompleted{
        id: event_id,
        phone: "5551234567",
        provider_type: "faraday",
        status: "success",
        enrichment_data: %{age: 35},
        timestamp: NaiveDateTime.utc_now()
      }

      append_event(event)

      assert_async do
        assert [] = Repo.all(PossibleAddress)
      end
    end

    test "ignores error status enrichment events" do
      event_id = Ecto.UUID.generate()

      event = %ProviderEnrichmentCompleted{
        id: event_id,
        phone: "5551234567",
        provider_type: "endato",
        status: "error",
        error_data: %{reason: "timeout"},
        timestamp: NaiveDateTime.utc_now()
      }

      append_event(event)

      assert_async do
        assert [] = Repo.all(PossibleAddress)
      end
    end

    test "ignores events with no addresses" do
      event_id = Ecto.UUID.generate()

      event = %ProviderEnrichmentCompleted{
        id: event_id,
        phone: "5551234567",
        provider_type: "endato",
        status: "success",
        enrichment_data: %{
          addresses: [],
          emails: ["foo@bar.com"]
        },
        timestamp: NaiveDateTime.utc_now()
      }

      append_event(event)

      assert_async do
        assert [] = Repo.all(PossibleAddress)
      end
    end

    test "ignores existing possible addresses (deduplication)" do
      # Create an existing address using the same ID generation logic
      enrichment_id = Ecto.UUID.generate()

      address_data = %{
        street_1: "123 Main St",
        street_2: "Unit 3",
        city: "Fooville",
        state: "OH",
        zip: "46862"
      }

      id = WaltUi.Projectors.PossibleAddress.to_id(enrichment_id, address_data)

      _existing_addr =
        insert(
          :possible_address,
          Map.put(address_data, :id, id) |> Map.put(:enrichment_id, enrichment_id)
        )

      # Try to create the same address via ProviderEnrichmentCompleted
      event = %ProviderEnrichmentCompleted{
        id: enrichment_id,
        phone: "5551234567",
        provider_type: "endato",
        status: "success",
        enrichment_data: %{
          addresses: [address_data],
          emails: ["foo@bar.com"]
        },
        timestamp: NaiveDateTime.utc_now()
      }

      append_event(event)

      assert_async do
        # Should still only have one address (the existing one)
        assert [%{enrichment_id: ^enrichment_id}] = Repo.all(PossibleAddress)
      end
    end

    test "handles multiple addresses in one event" do
      event_id = Ecto.UUID.generate()

      addresses = [
        %{
          street_1: "123 Main St",
          street_2: "Unit 3",
          city: "Fooville",
          state: "OH",
          zip: "46862"
        },
        %{
          street_1: "456 Oak Ave",
          street_2: nil,
          city: "Barville",
          state: "CA",
          zip: "90210"
        }
      ]

      event = %ProviderEnrichmentCompleted{
        id: event_id,
        phone: "5551234567",
        provider_type: "endato",
        status: "success",
        enrichment_data: %{
          addresses: addresses,
          emails: ["foo@bar.com"]
        },
        timestamp: NaiveDateTime.utc_now()
      }

      append_event(event)

      assert_async do
        addresses = Repo.all(PossibleAddress)
        assert length(addresses) == 2
        street_names = Enum.map(addresses, & &1.street_1)
        assert "123 Main St" in street_names
        assert "456 Oak Ave" in street_names
      end
    end

    test "comprehensive trestle address validation filtering" do
      event_id = Ecto.UUID.generate()

      addresses = [
        # Valid address
        %{
          street_1: "123 Main St",
          street_2: "Unit 3",
          city: "Fooville",
          state: "OH",
          zip: "46862"
        },
        # Invalid: empty city
        %{
          street_1: "456 Oak Ave",
          street_2: nil,
          city: "",
          state: "OH",
          zip: "46863"
        },
        # Invalid: nil state
        %{
          street_1: "789 Pine St",
          street_2: nil,
          city: "Barville",
          state: nil,
          zip: "46864"
        },
        # Invalid: whitespace-only zip
        %{
          street_1: "101 Elm St",
          street_2: nil,
          city: "Bazville",
          state: "OH",
          zip: "   "
        },
        # Another valid address
        %{
          street_1: "202 Cedar Ave",
          street_2: "Apt 2",
          city: "Quxville",
          state: "OH",
          zip: "46865"
        }
      ]

      event = %ProviderEnrichmentCompleted{
        id: event_id,
        phone: "5551234567",
        provider_type: "trestle",
        status: "success",
        enrichment_data: %{
          addresses: addresses,
          age_range: "35-44"
        },
        timestamp: NaiveDateTime.utc_now()
      }

      append_event(event)

      assert_async do
        addresses = Repo.all(PossibleAddress)
        # Only the 2 valid addresses should be projected
        assert length(addresses) == 2

        street_names = Enum.map(addresses, & &1.street_1)
        assert "123 Main St" in street_names
        assert "202 Cedar Ave" in street_names

        # Invalid addresses should not be present
        refute "456 Oak Ave" in street_names
        refute "789 Pine St" in street_names
        refute "101 Elm St" in street_names
      end
    end
  end
end
