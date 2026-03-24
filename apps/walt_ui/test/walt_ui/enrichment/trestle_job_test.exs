defmodule WaltUi.Enrichment.TrestleJobTest do
  use WaltUi.CqrsCase
  use Oban.Testing, repo: Repo
  use Mimic

  alias CQRS.Enrichments.Events.ProviderEnrichmentCompleted
  alias WaltUi.Enrichment.Trestle.Http
  alias WaltUi.Enrichment.TrestleJob

  @trestle_response %{
    "carrier" => "Verizon Wireless",
    "country_calling_code" => "1",
    "error" => nil,
    "id" => "Phone.abc123-def4-567g-hij8-klm901234567",
    "is_commercial" => false,
    "is_prepaid" => false,
    "is_valid" => true,
    "line_type" => "Mobile",
    "owners" => [
      %{
        "age_range" => "30-35",
        "alternate_names" => [],
        "alternate_phones" => [
          %{"lineType" => "Landline", "phoneNumber" => "+15551234567"}
        ],
        "current_addresses" => [
          %{
            "city" => "Columbus",
            "country_code" => nil,
            "delivery_point" => "SingleUnit",
            "id" => "Location.xyz789-abc1-def2-ghi3-jkl456789012",
            "lat_long" => %{
              "accuracy" => "RoofTop",
              "latitude" => 39.9612,
              "longitude" => -82.9988
            },
            "link_to_person_start_date" => "2020-01-01",
            "location_type" => "Address",
            "postal_code" => "43215",
            "state_code" => "OH",
            "street_line_1" => "123 Main St",
            "street_line_2" => nil,
            "zip4" => "1234"
          },
          %{
            "city" => "Dublin",
            "country_code" => nil,
            "delivery_point" => "SingleUnit",
            "id" => "Location.mno345-pqr6-stu7-vwx8-yz9012345678",
            "lat_long" => %{
              "accuracy" => "RoofTop",
              "latitude" => 40.0992,
              "longitude" => -83.1141
            },
            "link_to_person_start_date" => "2018-06-15",
            "location_type" => "Address",
            "postal_code" => "43017",
            "state_code" => "OH",
            "street_line_1" => "456 Oak Ave",
            "street_line_2" => "Apt 2B",
            "zip4" => "5678"
          }
        ],
        "emails" => ["john.smith@example.com", "jsmith@gmail.com"],
        "firstname" => "John",
        "gender" => "M",
        "id" => "Person.abc123-def4-567g-hij8-klm901234567",
        "industry" => nil,
        "lastname" => "Smith",
        "link_to_phone_start_date" => "2015-03-01",
        "middlename" => "Michael",
        "name" => "John Michael Smith",
        "type" => "Person"
      }
    ],
    "phone_number" => "+15559876543",
    "warnings" => []
  }

  @empty_response %{
    "error" => nil,
    "owners" => [],
    "phone_number" => "+15559876543",
    "warnings" => []
  }

  setup [:set_mimic_from_context, :verify_on_exit!]

  setup do
    # Save original client config
    original_client = Application.get_env(:walt_ui, WaltUi.Trestle)[:client]

    # Set client to real client module for testing
    Application.put_env(:walt_ui, WaltUi.Trestle, client: WaltUi.Enrichment.Trestle.Client)

    on_exit(fn ->
      # Restore original client config
      current_config = Application.get_env(:walt_ui, WaltUi.Trestle, [])
      new_config = Keyword.put(current_config, :client, original_client)
      Application.put_env(:walt_ui, WaltUi.Trestle, new_config)
    end)

    :ok
  end

  describe "process/1 with structured arguments" do
    test "dispatches CompleteProviderEnrichment command on successful enrichment" do
      enrichment_id = Ecto.UUID.generate()
      user_id = Ecto.UUID.generate()

      # Mock the Trestle API call
      expect(Http, :search_by_phone, fn _phone, _opts -> {:ok, @trestle_response} end)

      event = %{
        id: enrichment_id,
        provider_type: "trestle",
        contact_data: %{
          phone: "5559876543",
          first_name: "John",
          last_name: "Smith",
          email: "john@example.com",
          user_id: user_id
        },
        provider_config: %{},
        timestamp: NaiveDateTime.utc_now()
      }

      args = %{user_id: user_id, event: event}

      assert :ok = perform_job(TrestleJob, args)

      # Assert that a ProviderEnrichmentCompleted event was dispatched
      assert_receive_event(
        CQRS,
        ProviderEnrichmentCompleted,
        fn evt -> evt.id == enrichment_id && evt.provider_type == "trestle" end,
        fn evt ->
          assert evt.status == "success"
          assert evt.enrichment_data.age_range == "30-35"
          assert evt.enrichment_data.first_name == "John"
          assert evt.enrichment_data.last_name == "Smith"
          assert length(evt.enrichment_data.addresses) == 2
          assert length(evt.enrichment_data.emails) == 2
          assert evt.quality_metadata.match_count == 1
        end
      )
    end

    test "dispatches CompleteProviderEnrichment with error status when no owners found" do
      enrichment_id = Ecto.UUID.generate()
      user_id = Ecto.UUID.generate()

      # Mock the Trestle API call to return empty owners
      expect(Http, :search_by_phone, fn _phone, _opts -> {:ok, @empty_response} end)

      event = %{
        id: enrichment_id,
        provider_type: "trestle",
        contact_data: %{
          phone: "5559876543",
          first_name: "John",
          last_name: "Smith",
          user_id: user_id
        },
        provider_config: %{},
        timestamp: NaiveDateTime.utc_now()
      }

      args = %{user_id: user_id, event: event}

      assert :ok = perform_job(TrestleJob, args)

      # Verify the error event was dispatched
      assert_receive_event(
        CQRS,
        ProviderEnrichmentCompleted,
        fn evt -> evt.id == enrichment_id && evt.provider_type == "trestle" end,
        fn evt ->
          assert evt.status == "error"
          assert evt.enrichment_data == nil
          assert evt.error_data.reason == :no_owners_found
        end
      )
    end

    test "works with nil user_id" do
      enrichment_id = Ecto.UUID.generate()

      # Mock the Trestle API call
      expect(Http, :search_by_phone, fn _phone, _opts -> {:ok, @trestle_response} end)

      event = %{
        id: enrichment_id,
        provider_type: "trestle",
        contact_data: %{
          phone: "5559876543",
          first_name: "John",
          last_name: "Smith",
          email: "john@example.com",
          user_id: nil
        },
        provider_config: %{},
        timestamp: NaiveDateTime.utc_now()
      }

      args = %{user_id: nil, event: event}

      assert :ok = perform_job(TrestleJob, args)

      # Should still process successfully
      assert_receive_event(
        CQRS,
        ProviderEnrichmentCompleted,
        fn evt -> evt.id == enrichment_id && evt.provider_type == "trestle" end,
        fn evt ->
          assert evt.status == "success"
        end
      )
    end

    test "dispatches CompleteProviderEnrichment with error status on API failure" do
      enrichment_id = Ecto.UUID.generate()
      user_id = Ecto.UUID.generate()

      # Mock the Trestle API call to fail
      expect(Http, :search_by_phone, fn _phone, _opts -> {:error, "API timeout"} end)

      event = %{
        id: enrichment_id,
        provider_type: "trestle",
        contact_data: %{
          phone: "5559876543",
          first_name: "John",
          last_name: "Smith",
          user_id: user_id
        },
        provider_config: %{},
        timestamp: NaiveDateTime.utc_now()
      }

      args = %{user_id: user_id, event: event}

      assert :ok = perform_job(TrestleJob, args)

      # Verify the error event was dispatched
      assert_receive_event(
        CQRS,
        ProviderEnrichmentCompleted,
        fn evt -> evt.id == enrichment_id && evt.provider_type == "trestle" end,
        fn evt ->
          assert evt.status == "error"
          assert evt.enrichment_data == nil
          assert evt.error_data.reason == "API timeout"
        end
      )
    end

    test "selects best matching owner in new enrichment flow" do
      enrichment_id = Ecto.UUID.generate()
      user_id = Ecto.UUID.generate()

      multiple_owners_response = %{
        @trestle_response
        | "owners" => [
            %{
              "firstname" => "Bob",
              "lastname" => "Johnson",
              "emails" => ["bob@example.com"],
              "current_addresses" => []
            },
            %{
              "firstname" => "Jane",
              "lastname" => "Smith",
              "emails" => ["jane@example.com"],
              "current_addresses" => []
            },
            %{
              "firstname" => "John",
              "lastname" => "Doe",
              "emails" => ["johndoe@example.com"],
              "current_addresses" => []
            }
          ]
      }

      expect(Http, :search_by_phone, fn _phone, _opts -> {:ok, multiple_owners_response} end)

      event = %{
        id: enrichment_id,
        provider_type: "trestle",
        contact_data: %{
          phone: "5559876543",
          first_name: "Jane",
          last_name: "Smith",
          email: "jane.smith@company.com",
          user_id: user_id
        },
        provider_config: %{},
        timestamp: NaiveDateTime.utc_now()
      }

      args = %{user_id: user_id, event: event}

      assert :ok = perform_job(TrestleJob, args)

      assert_receive_event(
        CQRS,
        ProviderEnrichmentCompleted,
        fn evt -> evt.id == enrichment_id end,
        fn evt ->
          # Should select Jane Smith as it exactly matches the name hint
          assert evt.enrichment_data.first_name == "Jane"
          assert evt.enrichment_data.last_name == "Smith"
          assert evt.enrichment_data.emails == ["jane@example.com"]
          assert evt.quality_metadata.match_count == 3
        end
      )
    end

    test "selects owner by alternate name match in new enrichment flow" do
      enrichment_id = Ecto.UUID.generate()
      user_id = Ecto.UUID.generate()

      multiple_owners_response = %{
        @trestle_response
        | "owners" => [
            %{
              "firstname" => "Bob",
              "lastname" => "Johnson",
              "emails" => ["bob@example.com"],
              "current_addresses" => [],
              "alternate_names" => ["Robert Johnson"]
            },
            %{
              "firstname" => "Andrew",
              "lastname" => "Sedlak",
              "emails" => ["andrew@example.com"],
              "current_addresses" => [],
              "alternate_names" => ["Andy J Sedlak"]
            },
            %{
              "firstname" => "John",
              "lastname" => "Doe",
              "emails" => ["johndoe@example.com"],
              "current_addresses" => [],
              "alternate_names" => []
            }
          ]
      }

      expect(Http, :search_by_phone, fn _phone, _opts -> {:ok, multiple_owners_response} end)

      event = %{
        id: enrichment_id,
        provider_type: "trestle",
        contact_data: %{
          phone: "5559876543",
          first_name: "Andy",
          last_name: "Sedlak",
          email: "andy.sedlak@company.com",
          user_id: user_id
        },
        provider_config: %{},
        timestamp: NaiveDateTime.utc_now()
      }

      args = %{user_id: user_id, event: event}

      assert :ok = perform_job(TrestleJob, args)

      assert_receive_event(
        CQRS,
        ProviderEnrichmentCompleted,
        fn evt -> evt.id == enrichment_id end,
        fn evt ->
          # Should select Andrew Sedlak as "Andy Sedlak" matches his alternate name
          assert evt.enrichment_data.first_name == "Andrew"
          assert evt.enrichment_data.last_name == "Sedlak"
          assert evt.enrichment_data.emails == ["andrew@example.com"]
          assert evt.quality_metadata.match_count == 3
        end
      )
    end

    test "includes alternate names in enrichment data when present" do
      enrichment_id = Ecto.UUID.generate()
      user_id = Ecto.UUID.generate()

      # Create a response with alternate names
      response_with_alternate_names = %{
        @trestle_response
        | "owners" => [
            %{
              "age_range" => "30-35",
              "alternate_names" => ["Bill Smith", "Will Smith", "Billy Smith"],
              "current_addresses" => [],
              "emails" => ["john.smith@example.com"],
              "firstname" => "William",
              "lastname" => "Smith",
              "id" => "Person.abc123-def4-567g-hij8-klm901234567"
            }
          ]
      }

      expect(Http, :search_by_phone, fn _phone, _opts -> {:ok, response_with_alternate_names} end)

      event = %{
        id: enrichment_id,
        provider_type: "trestle",
        contact_data: %{
          phone: "5559876543",
          first_name: "William",
          last_name: "Smith",
          user_id: user_id
        },
        provider_config: %{},
        timestamp: NaiveDateTime.utc_now()
      }

      args = %{user_id: user_id, event: event}

      assert :ok = perform_job(TrestleJob, args)

      assert_receive_event(
        CQRS,
        ProviderEnrichmentCompleted,
        fn evt -> evt.id == enrichment_id && evt.provider_type == "trestle" end,
        fn evt ->
          assert evt.status == "success"

          assert evt.enrichment_data[:alternate_names] == [
                   "Bill Smith",
                   "Will Smith",
                   "Billy Smith"
                 ]
        end
      )
    end

    test "includes empty array when alternate names missing" do
      enrichment_id = Ecto.UUID.generate()
      user_id = Ecto.UUID.generate()

      # Create a response without alternate names field
      response_without_alternate_names = %{
        @trestle_response
        | "owners" => [
            %{
              "age_range" => "30-35",
              "current_addresses" => [],
              "emails" => ["john.smith@example.com"],
              "firstname" => "John",
              "lastname" => "Smith",
              "id" => "Person.abc123-def4-567g-hij8-klm901234567"
              # alternate_names key not present
            }
          ]
      }

      expect(Http, :search_by_phone, fn _phone, _opts ->
        {:ok, response_without_alternate_names}
      end)

      event = %{
        id: enrichment_id,
        provider_type: "trestle",
        contact_data: %{
          phone: "5559876543",
          first_name: "John",
          last_name: "Smith",
          user_id: user_id
        },
        provider_config: %{},
        timestamp: NaiveDateTime.utc_now()
      }

      args = %{user_id: user_id, event: event}

      assert :ok = perform_job(TrestleJob, args)

      assert_receive_event(
        CQRS,
        ProviderEnrichmentCompleted,
        fn evt -> evt.id == enrichment_id && evt.provider_type == "trestle" end,
        fn evt ->
          assert evt.status == "success"
          assert evt.enrichment_data[:alternate_names] == []
        end
      )
    end

    test "includes empty array when alternate names is nil" do
      enrichment_id = Ecto.UUID.generate()
      user_id = Ecto.UUID.generate()

      # Create a response with nil alternate names
      response_with_nil_alternate_names = %{
        @trestle_response
        | "owners" => [
            %{
              "age_range" => "30-35",
              "alternate_names" => nil,
              "current_addresses" => [],
              "emails" => ["john.smith@example.com"],
              "firstname" => "John",
              "lastname" => "Smith",
              "id" => "Person.abc123-def4-567g-hij8-klm901234567"
            }
          ]
      }

      expect(Http, :search_by_phone, fn _phone, _opts ->
        {:ok, response_with_nil_alternate_names}
      end)

      event = %{
        id: enrichment_id,
        provider_type: "trestle",
        contact_data: %{
          phone: "5559876543",
          first_name: "John",
          last_name: "Smith",
          user_id: user_id
        },
        provider_config: %{},
        timestamp: NaiveDateTime.utc_now()
      }

      args = %{user_id: user_id, event: event}

      assert :ok = perform_job(TrestleJob, args)

      assert_receive_event(
        CQRS,
        ProviderEnrichmentCompleted,
        fn evt -> evt.id == enrichment_id && evt.provider_type == "trestle" end,
        fn evt ->
          assert evt.status == "success"
          assert evt.enrichment_data[:alternate_names] == []
        end
      )
    end

    test "filters out PO Box addresses from enrichment data" do
      enrichment_id = Ecto.UUID.generate()
      user_id = Ecto.UUID.generate()

      response_with_po_box = %{
        @trestle_response
        | "owners" => [
            %{
              "age_range" => "30-35",
              "alternate_names" => [],
              "current_addresses" => [
                %{
                  "city" => "Columbus",
                  "postal_code" => "43215",
                  "state_code" => "OH",
                  "street_line_1" => "PO Box 12345",
                  "street_line_2" => nil
                },
                %{
                  "city" => "Columbus",
                  "postal_code" => "43215",
                  "state_code" => "OH",
                  "street_line_1" => "P.O. Box 67890",
                  "street_line_2" => nil
                },
                %{
                  "city" => "Dublin",
                  "postal_code" => "43017",
                  "state_code" => "OH",
                  "street_line_1" => "123 Main St",
                  "street_line_2" => "Apt 2B"
                }
              ],
              "emails" => ["john.smith@example.com"],
              "firstname" => "John",
              "lastname" => "Smith",
              "id" => "Person.abc123-def4-567g-hij8-klm901234567"
            }
          ]
      }

      expect(Http, :search_by_phone, fn _phone, _opts -> {:ok, response_with_po_box} end)

      event = %{
        id: enrichment_id,
        provider_type: "trestle",
        contact_data: %{
          phone: "5559876543",
          first_name: "John",
          last_name: "Smith",
          user_id: user_id
        },
        provider_config: %{},
        timestamp: NaiveDateTime.utc_now()
      }

      args = %{user_id: user_id, event: event}

      assert :ok = perform_job(TrestleJob, args)

      assert_receive_event(
        CQRS,
        ProviderEnrichmentCompleted,
        fn evt -> evt.id == enrichment_id && evt.provider_type == "trestle" end,
        fn evt ->
          assert evt.status == "success"
          # Only the non-PO Box address should remain
          assert length(evt.enrichment_data.addresses) == 1
          [address] = evt.enrichment_data.addresses
          assert address.street_1 == "123 Main St"
          assert address.city == "Dublin"
        end
      )
    end

    test "returns empty addresses list when all addresses are PO Boxes" do
      enrichment_id = Ecto.UUID.generate()
      user_id = Ecto.UUID.generate()

      response_all_po_boxes = %{
        @trestle_response
        | "owners" => [
            %{
              "age_range" => "30-35",
              "alternate_names" => [],
              "current_addresses" => [
                %{
                  "city" => "Columbus",
                  "postal_code" => "43215",
                  "state_code" => "OH",
                  "street_line_1" => "PO Box 12345",
                  "street_line_2" => nil
                },
                %{
                  "city" => "Columbus",
                  "postal_code" => "43215",
                  "state_code" => "OH",
                  "street_line_1" => "po box 67890",
                  "street_line_2" => nil
                }
              ],
              "emails" => ["john.smith@example.com"],
              "firstname" => "John",
              "lastname" => "Smith",
              "id" => "Person.abc123-def4-567g-hij8-klm901234567"
            }
          ]
      }

      expect(Http, :search_by_phone, fn _phone, _opts -> {:ok, response_all_po_boxes} end)

      event = %{
        id: enrichment_id,
        provider_type: "trestle",
        contact_data: %{
          phone: "5559876543",
          first_name: "John",
          last_name: "Smith",
          user_id: user_id
        },
        provider_config: %{},
        timestamp: NaiveDateTime.utc_now()
      }

      args = %{user_id: user_id, event: event}

      assert :ok = perform_job(TrestleJob, args)

      assert_receive_event(
        CQRS,
        ProviderEnrichmentCompleted,
        fn evt -> evt.id == enrichment_id && evt.provider_type == "trestle" end,
        fn evt ->
          assert evt.status == "success"
          # All addresses should be filtered out
          assert evt.enrichment_data.addresses == []
        end
      )
    end
  end
end
