defmodule WaltUi.ProcessManagers.UnificationManagerTest do
  use WaltUi.CqrsCase
  use Mimic
  use Oban.Testing, repo: Repo

  import WaltUi.Factory

  alias CQRS.Enrichments.Commands.RequestEnrichment
  alias CQRS.Enrichments.Events.EnrichmentRequested
  alias CQRS.Leads.Commands.Unify
  alias CQRS.Leads.Events.LeadCreated
  alias WaltUi.Enrichment.OpenAi
  alias WaltUi.Enrichment.UnificationJob
  alias WaltUi.ProcessManagers.UnificationManager

  setup [:set_mimic_global, :verify_on_exit!]

  describe "interested?/1" do
    test "starts process manager for LeadCreated events" do
      lead_id = Ecto.UUID.generate()
      user_id = Ecto.UUID.generate()

      event = %LeadCreated{
        id: lead_id,
        user_id: user_id,
        timestamp: NaiveDateTime.utc_now(),
        first_name: "John",
        last_name: "Doe",
        phone: "5551234567",
        email: "john@example.com"
      }

      assert UnificationManager.interested?(event) == {:start, lead_id}
    end

    test "ignores non-LeadCreated events" do
      event = %EnrichmentRequested{
        id: Ecto.UUID.generate(),
        phone: "5551234567",
        user_id: Ecto.UUID.generate(),
        timestamp: NaiveDateTime.utc_now()
      }

      assert UnificationManager.interested?(event) == false
    end
  end

  describe "apply/2" do
    test "updates state with event ID" do
      initial_state = %UnificationManager{id: nil}
      lead_id = Ecto.UUID.generate()
      user_id = Ecto.UUID.generate()

      event = %LeadCreated{
        id: lead_id,
        user_id: user_id,
        timestamp: NaiveDateTime.utc_now(),
        first_name: "John",
        last_name: "Doe",
        phone: "5551234567"
      }

      new_state = UnificationManager.apply(initial_state, event)

      assert new_state.id == lead_id
    end
  end

  describe "handle/2 - successful unification" do
    test "returns RequestEnrichment when only Faraday record exists (no Trestle for name matching)" do
      lead_id = Ecto.UUID.generate()
      user_id = Ecto.UUID.generate()
      phone = "5551234567"

      # Create Faraday record in database using factory (no Trestle)
      _faraday_record =
        insert(:faraday, %{
          id: UUID.uuid5(:oid, phone),
          first_name: "John",
          last_name: "Doe",
          address: "123 Main St",
          city: "Columbus",
          state: "OH",
          postcode: "43215",
          propensity_to_transact: 0.85,
          match_type: "address_full_name"
        })

      event = %LeadCreated{
        id: lead_id,
        user_id: user_id,
        timestamp: NaiveDateTime.utc_now(),
        first_name: "John",
        last_name: "Doe",
        phone: phone,
        email: "john@example.com"
      }

      result = UnificationManager.handle(%UnificationManager{}, event)

      # Should request enrichment since no Trestle data for name matching
      assert %RequestEnrichment{} = result
      assert result.phone == phone
      assert result.first_name == "John"
      assert result.last_name == "Doe"
      assert result.email == "john@example.com"
    end

    test "returns RequestEnrichment for Faraday-only data regardless of match_type" do
      lead_id = Ecto.UUID.generate()
      user_id = Ecto.UUID.generate()
      phone = "5551234567"

      # Test with different match_type (Faraday-only)
      insert(:faraday, %{
        id: UUID.uuid5(:oid, phone),
        first_name: "John",
        last_name: "Smith",
        address: "456 Oak Ave",
        city: "Dublin",
        state: "OH",
        postcode: "43017",
        propensity_to_transact: 0.75,
        match_type: "phone_full_name"
      })

      event = %LeadCreated{
        id: lead_id,
        user_id: user_id,
        timestamp: NaiveDateTime.utc_now(),
        first_name: "John",
        last_name: "Smith",
        phone: phone
      }

      result = UnificationManager.handle(%UnificationManager{}, event)

      # Should request enrichment since no Trestle data for name matching
      assert %RequestEnrichment{} = result
      assert result.phone == phone
      assert result.first_name == "John"
      assert result.last_name == "Smith"
    end

    test "returns RequestEnrichment for Faraday-only data with nil match_type" do
      lead_id = Ecto.UUID.generate()
      user_id = Ecto.UUID.generate()
      phone = "5559876543"

      insert(:faraday, %{
        id: UUID.uuid5(:oid, phone),
        first_name: "Jane",
        last_name: "Doe",
        address: "789 Elm St",
        city: "Cleveland",
        state: "OH",
        postcode: "44101",
        propensity_to_transact: 0.65,
        match_type: nil
      })

      event = %LeadCreated{
        id: lead_id,
        user_id: user_id,
        timestamp: NaiveDateTime.utc_now(),
        first_name: "Jane",
        last_name: "Doe",
        phone: phone
      }

      result = UnificationManager.handle(%UnificationManager{}, event)

      # Should request enrichment since no Trestle data for name matching
      assert %RequestEnrichment{} = result
      assert result.phone == phone
      assert result.first_name == "Jane"
      assert result.last_name == "Doe"
    end
  end

  describe "handle/2 - request enrichment" do
    test "returns RequestEnrichment command when no Faraday record exists" do
      lead_id = Ecto.UUID.generate()
      user_id = Ecto.UUID.generate()
      phone = "5551234567"

      # Don't create any Faraday record - should trigger RequestEnrichment

      event = %LeadCreated{
        id: lead_id,
        user_id: user_id,
        timestamp: NaiveDateTime.utc_now(),
        first_name: "John",
        last_name: "Doe",
        phone: phone,
        email: "john@example.com"
      }

      result = UnificationManager.handle(%UnificationManager{}, event)

      assert %RequestEnrichment{} = result
      assert result.phone == phone
      assert result.first_name == "John"
      assert result.last_name == "Doe"
      assert result.email == "john@example.com"
    end
  end

  describe "handle/2 - validation failures" do
    test "returns empty list for invalid phone number" do
      lead_id = Ecto.UUID.generate()
      user_id = Ecto.UUID.generate()

      event = %LeadCreated{
        id: lead_id,
        user_id: user_id,
        timestamp: NaiveDateTime.utc_now(),
        first_name: "John",
        last_name: "Doe",
        # Invalid phone - not 10 digits
        phone: "123",
        email: "john@example.com"
      }

      result = UnificationManager.handle(%UnificationManager{}, event)

      assert result == []
    end

    test "returns empty list for familial names" do
      lead_id = Ecto.UUID.generate()
      user_id = Ecto.UUID.generate()

      event = %LeadCreated{
        id: lead_id,
        user_id: user_id,
        timestamp: NaiveDateTime.utc_now(),
        # Familial name
        first_name: "wife",
        last_name: "Doe",
        phone: "5551234567",
        email: "wife@example.com"
      }

      result = UnificationManager.handle(%UnificationManager{}, event)

      assert result == []
    end

    test "returns RequestEnrichment for Faraday-only data (can't do name matching)" do
      lead_id = Ecto.UUID.generate()
      user_id = Ecto.UUID.generate()
      phone = "5551234567"

      # Create Faraday record with completely different names (no Trestle)
      insert(:faraday, %{
        id: UUID.uuid5(:oid, phone),
        first_name: "Michael",
        last_name: "Johnson",
        address: "123 Main St",
        city: "Columbus",
        state: "OH",
        postcode: "43215",
        propensity_to_transact: 0.85,
        match_type: "address_full_name"
      })

      event = %LeadCreated{
        id: lead_id,
        user_id: user_id,
        timestamp: NaiveDateTime.utc_now(),
        first_name: "John",
        last_name: "Doe",
        phone: phone,
        email: "john@example.com"
      }

      result = UnificationManager.handle(%UnificationManager{}, event)

      # Should request enrichment since no Trestle data for name matching
      assert %RequestEnrichment{} = result
      assert result.phone == phone
      assert result.first_name == "John"
      assert result.last_name == "Doe"
      assert result.email == "john@example.com"
    end

    test "returns RequestEnrichment for Faraday-only scenarios regardless of OpenAI timeout" do
      lead_id = Ecto.UUID.generate()
      user_id = Ecto.UUID.generate()
      phone = "5551234567"

      # Create Faraday record with names that fail Jaro distance (no Trestle)
      insert(:faraday, %{
        id: UUID.uuid5(:oid, phone),
        # Different enough to fail Jaro but could be same person
        first_name: "Jonathan",
        last_name: "Smith",
        address: "123 Main St",
        city: "Columbus",
        state: "OH",
        postcode: "43215",
        propensity_to_transact: 0.85,
        match_type: "address_full_name"
      })

      event = %LeadCreated{
        id: lead_id,
        user_id: user_id,
        timestamp: NaiveDateTime.utc_now(),
        first_name: "John",
        last_name: "Doe",
        phone: phone,
        email: "john@example.com"
      }

      result = UnificationManager.handle(%UnificationManager{}, event)

      # Should request enrichment since no Trestle data for name matching
      assert %RequestEnrichment{} = result
      assert result.phone == phone
      assert result.first_name == "John"
      assert result.last_name == "Doe"
      assert result.email == "john@example.com"
    end
  end

  describe "handle/2 - flexible data scenarios" do
    test "unifies with Trestle + Faraday data using Faraday address and Faraday Move Score" do
      lead_id = Ecto.UUID.generate()
      user_id = Ecto.UUID.generate()
      phone = "5551234567"
      enrichment_id = UUID.uuid5(:oid, phone)

      # Create both projections with same ID
      insert(:faraday, %{
        id: enrichment_id,
        first_name: "John",
        last_name: "Doe",
        # Should be used (Faraday address preferred)
        address: "123 Faraday Address",
        city: "Faraday City",
        state: "FC",
        postcode: "00000",
        propensity_to_transact: 0.85,
        match_type: "address_full_name"
      })

      insert(:trestle, %{
        id: enrichment_id,
        first_name: "John",
        last_name: "Doe",
        addresses: [
          %{
            # Should NOT be used (Faraday takes precedence)
            street_1: "123 Trestle St",
            street_2: "Apt 4B",
            city: "Trestle City",
            state: "TC",
            zip: "12345"
          }
        ],
        alternate_names: []
      })

      OpenAi
      |> stub(:confirm_identity, fn _contact, _service_data ->
        {:ok, true}
      end)

      event = %LeadCreated{
        id: lead_id,
        user_id: user_id,
        timestamp: NaiveDateTime.utc_now(),
        first_name: "John",
        last_name: "Doe",
        phone: phone,
        email: "john@example.com"
      }

      result = UnificationManager.handle(%UnificationManager{}, event)

      assert %Unify{} = result
      assert result.id == lead_id
      assert result.enrichment_id == enrichment_id
      # Should use Faraday enrichment type and Move Score
      assert result.enrichment_type == :best
      assert result.ptt == 85
      # Should use Faraday address data (preferred over Trestle)
      assert result.street_1 == "123 Faraday Address"
      assert result.city == "Faraday City"
      assert result.state == "FC"
      assert result.zip == "00000"
    end

    test "unifies with Trestle-only data, no Move Score" do
      lead_id = Ecto.UUID.generate()
      user_id = Ecto.UUID.generate()
      phone = "5559876543"
      enrichment_id = UUID.uuid5(:oid, phone)

      # Only create Trestle projection
      insert(:trestle, %{
        id: enrichment_id,
        first_name: "Jane",
        last_name: "Smith",
        addresses: [
          %{
            street_1: "456 Trestle Ave",
            street_2: nil,
            city: "Smith City",
            state: "SC",
            zip: "54321"
          }
        ],
        alternate_names: []
      })

      OpenAi
      |> stub(:confirm_identity, fn _contact, _service_data ->
        {:ok, true}
      end)

      event = %LeadCreated{
        id: lead_id,
        user_id: user_id,
        timestamp: NaiveDateTime.utc_now(),
        first_name: "Jane",
        last_name: "Smith",
        phone: phone,
        email: "jane@example.com"
      }

      result = UnificationManager.handle(%UnificationManager{}, event)

      assert %Unify{} = result
      assert result.id == lead_id
      assert result.enrichment_id == enrichment_id
      # Should default enrichment type and Move Score when no Faraday
      assert result.enrichment_type == :lesser
      assert result.ptt == 0
      # Should use Trestle address data
      assert result.street_1 == "456 Trestle Ave"
      assert result.city == "Smith City"
      assert result.state == "SC"
      assert result.zip == "54321"
    end

    test "falls back to RequestEnrichment when neither projection exists" do
      lead_id = Ecto.UUID.generate()
      user_id = Ecto.UUID.generate()
      phone = "5552468135"

      # Don't create any projections

      event = %LeadCreated{
        id: lead_id,
        user_id: user_id,
        timestamp: NaiveDateTime.utc_now(),
        first_name: "Bob",
        last_name: "Wilson",
        phone: phone,
        email: "bob@example.com"
      }

      result = UnificationManager.handle(%UnificationManager{}, event)

      assert %RequestEnrichment{} = result
      assert result.phone == phone
      assert result.first_name == "Bob"
      assert result.last_name == "Wilson"
      assert result.email == "bob@example.com"
    end

    test "falls back to RequestEnrichment when only Faraday exists" do
      lead_id = Ecto.UUID.generate()
      user_id = Ecto.UUID.generate()
      phone = "5557531598"
      enrichment_id = UUID.uuid5(:oid, phone)

      # Only create Faraday projection (no Trestle for name matching)
      insert(:faraday, %{
        id: enrichment_id,
        first_name: "Mike",
        last_name: "Brown",
        address: "789 Faraday Blvd",
        city: "Faraday Town",
        state: "FT",
        postcode: "98765",
        propensity_to_transact: 0.75,
        match_type: "phone_full_name"
      })

      event = %LeadCreated{
        id: lead_id,
        user_id: user_id,
        timestamp: NaiveDateTime.utc_now(),
        first_name: "Mike",
        last_name: "Brown",
        phone: phone,
        email: "mike@example.com"
      }

      result = UnificationManager.handle(%UnificationManager{}, event)

      # Should fall back to RequestEnrichment since no Trestle for name matching
      assert %RequestEnrichment{} = result
      assert result.phone == phone
      assert result.first_name == "Mike"
      assert result.last_name == "Brown"
    end
  end

  describe "handle/2 - alternate names matching" do
    test "matches via primary Jaro distance (existing behavior preserved)" do
      lead_id = Ecto.UUID.generate()
      user_id = Ecto.UUID.generate()
      phone = "5551357924"
      enrichment_id = UUID.uuid5(:oid, phone)

      insert(:trestle, %{
        id: enrichment_id,
        first_name: "John",
        last_name: "Smith",
        addresses: [
          %{
            street_1: "111 Primary St",
            street_2: nil,
            city: "Primary City",
            state: "PC",
            zip: "11111"
          }
        ],
        # Should not be needed
        alternate_names: ["Johnny Smith", "J Smith"]
      })

      # Don't expect OpenAI to be called since primary Jaro should succeed
      OpenAi
      |> stub(:confirm_identity, fn _contact, _service_data ->
        flunk("OpenAI should not be called for direct Jaro match")
      end)

      event = %LeadCreated{
        id: lead_id,
        user_id: user_id,
        timestamp: NaiveDateTime.utc_now(),
        # Exact match
        first_name: "John",
        # Exact match
        last_name: "Smith",
        phone: phone,
        email: "john@example.com"
      }

      result = UnificationManager.handle(%UnificationManager{}, event)

      assert %Unify{} = result
      assert result.id == lead_id
      assert result.enrichment_id == enrichment_id
    end

    test "matches via alternate names when primary Jaro fails" do
      lead_id = Ecto.UUID.generate()
      user_id = Ecto.UUID.generate()
      phone = "5558642975"
      enrichment_id = UUID.uuid5(:oid, phone)

      insert(:trestle, %{
        id: enrichment_id,
        # Low Jaro vs "Bill"
        first_name: "William",
        last_name: "Johnson",
        addresses: [
          %{
            street_1: "222 Alternate St",
            street_2: nil,
            city: "Alternate City",
            state: "AC",
            zip: "22222"
          }
        ],
        alternate_names: ["Bill Johnson", "Billy Johnson", "Will Johnson"]
      })

      # Don't expect OpenAI to be called since alternate names should match
      OpenAi
      |> stub(:confirm_identity, fn _contact, _service_data ->
        flunk("OpenAI should not be called when alternate names match")
      end)

      event = %LeadCreated{
        id: lead_id,
        user_id: user_id,
        timestamp: NaiveDateTime.utc_now(),
        # Should match "Bill Johnson" in alternates
        first_name: "Bill",
        last_name: "Johnson",
        phone: phone,
        email: "bill@example.com"
      }

      result = UnificationManager.handle(%UnificationManager{}, event)

      assert %Unify{} = result
      assert result.id == lead_id
      assert result.enrichment_id == enrichment_id
    end

    test "schedules UnificationJob when both primary and alternate Jaro fail" do
      lead_id = Ecto.UUID.generate()
      user_id = Ecto.UUID.generate()
      phone = "5553691472"
      enrichment_id = UUID.uuid5(:oid, phone)

      insert(:trestle, %{
        id: enrichment_id,
        # Low Jaro vs "Bob"
        first_name: "Alexander",
        last_name: "Johnson",
        addresses: [
          %{
            street_1: "333 OpenAI St",
            street_2: nil,
            city: "OpenAI City",
            state: "OC",
            zip: "33333"
          }
        ],
        # No match for "Bob"
        alternate_names: ["Alex Johnson", "Al Johnson"]
      })

      event = %LeadCreated{
        id: lead_id,
        user_id: user_id,
        timestamp: NaiveDateTime.utc_now(),
        # No Jaro match with Alexander or alternates
        first_name: "Bob",
        last_name: "Johnson",
        phone: phone,
        email: "bob@example.com"
      }

      Oban.Testing.with_testing_mode(:manual, fn ->
        result = UnificationManager.handle(%UnificationManager{}, event)

        # Should return [] (job scheduled) instead of Unify command
        assert result == []

        # Verify UnificationJob was enqueued with correct arguments
        assert_enqueued(
          worker: UnificationJob,
          args: %{
            "contact_id" => lead_id,
            "contact_first_name" => "Bob",
            "contact_last_name" => "Johnson",
            "enrichment_id" => enrichment_id,
            "enrichment_first_name" => "Alexander",
            "enrichment_last_name" => "Johnson",
            "enrichment_alternate_names" => ["Alex Johnson", "Al Johnson"],
            "user_id" => user_id
          }
        )
      end)
    end

    test "falls back to RequestEnrichment when all matching fails" do
      lead_id = Ecto.UUID.generate()
      user_id = Ecto.UUID.generate()
      phone = "5554827396"
      enrichment_id = UUID.uuid5(:oid, phone)

      insert(:trestle, %{
        id: enrichment_id,
        first_name: "Alexander",
        last_name: "Johnson",
        addresses: [
          %{
            street_1: "444 Fail St",
            street_2: nil,
            city: "Fail City",
            state: "FC",
            zip: "44444"
          }
        ],
        alternate_names: ["Alex Johnson", "Al Johnson"]
      })

      # OpenAI rejects the match
      OpenAi
      |> expect(:confirm_identity, fn _contact, service_data ->
        assert service_data.alternate_names == ["Alex Johnson", "Al Johnson"]
        {:ok, false}
      end)

      event = %LeadCreated{
        id: lead_id,
        user_id: user_id,
        timestamp: NaiveDateTime.utc_now(),
        # No match anywhere
        first_name: "Robert",
        # No match anywhere
        last_name: "Brown",
        phone: phone,
        email: "robert@example.com"
      }

      result = UnificationManager.handle(%UnificationManager{}, event)

      # Should return empty list (no unification)
      assert result == []
    end
  end

  describe "handle/2 - UnificationJob scheduling" do
    test "schedules UnificationJob with correct alternate names" do
      lead_id = Ecto.UUID.generate()
      user_id = Ecto.UUID.generate()
      phone = "5559628375"
      enrichment_id = UUID.uuid5(:oid, phone)

      insert(:trestle, %{
        id: enrichment_id,
        first_name: "Christopher",
        last_name: "Anderson",
        addresses: [
          %{
            street_1: "888 OpenAI Test St",
            street_2: nil,
            city: "Test City",
            state: "TC",
            zip: "88888"
          }
        ],
        alternate_names: ["Chris Anderson", "Christie Anderson", "Topher Anderson"]
      })

      event = %LeadCreated{
        id: lead_id,
        user_id: user_id,
        timestamp: NaiveDateTime.utc_now(),
        # No Jaro match, should schedule job
        first_name: "Chuck",
        last_name: "Anderson",
        phone: phone,
        email: "chuck@example.com"
      }

      Oban.Testing.with_testing_mode(:manual, fn ->
        result = UnificationManager.handle(%UnificationManager{}, event)

        # Should return [] (job scheduled) instead of Unify command
        assert result == []

        # Verify UnificationJob was enqueued with correct alternate names
        assert_enqueued(
          worker: UnificationJob,
          args: %{
            "contact_id" => lead_id,
            "contact_first_name" => "Chuck",
            "contact_last_name" => "Anderson",
            "enrichment_id" => enrichment_id,
            "enrichment_first_name" => "Christopher",
            "enrichment_last_name" => "Anderson",
            "enrichment_alternate_names" => [
              "Chris Anderson",
              "Christie Anderson",
              "Topher Anderson"
            ],
            "user_id" => user_id
          }
        )
      end)
    end

    test "unifies immediately when alternate names match (Trestle + Faraday data)" do
      lead_id = Ecto.UUID.generate()
      user_id = Ecto.UUID.generate()
      phone = "5551739584"
      enrichment_id = UUID.uuid5(:oid, phone)

      insert(:faraday, %{
        id: enrichment_id,
        first_name: "Elizabeth",
        last_name: "Martinez",
        address: "999 Faraday St",
        city: "Faraday City",
        state: "FC",
        postcode: "99999",
        propensity_to_transact: 0.85,
        match_type: "address_full_name"
      })

      insert(:trestle, %{
        id: enrichment_id,
        first_name: "Elizabeth",
        last_name: "Martinez",
        addresses: [
          %{
            street_1: "999 Trestle St",
            street_2: nil,
            city: "Trestle City",
            state: "TC",
            zip: "99999"
          }
        ],
        alternate_names: ["Liz Martinez", "Beth Martinez", "Lizzy Martinez"]
      })

      event = %LeadCreated{
        id: lead_id,
        user_id: user_id,
        timestamp: NaiveDateTime.utc_now(),
        # Could be Elizabeth variation, but Jaro fails
        first_name: "Betty",
        last_name: "Martinez",
        phone: phone,
        email: "betty@example.com"
      }

      result = UnificationManager.handle(%UnificationManager{}, event)

      # Should unify immediately via alternate names ("Betty" matches "Beth")
      assert %Unify{} = result
      assert result.id == lead_id
      assert result.enrichment_id == enrichment_id
      # Should use Faraday enrichment type and Move Score
      assert result.enrichment_type == :best
      assert result.ptt == 85
      # Should use Faraday address data (preferred over Trestle)
      assert result.street_1 == "999 Faraday St"
      assert result.city == "Faraday City"
      assert result.state == "FC"
      assert result.zip == "99999"
    end

    test "schedules UnificationJob for non-matching names with different last names" do
      lead_id = Ecto.UUID.generate()
      user_id = Ecto.UUID.generate()
      phone = "5554862719"
      enrichment_id = UUID.uuid5(:oid, phone)

      insert(:trestle, %{
        id: enrichment_id,
        first_name: "Jennifer",
        last_name: "Garcia",
        addresses: [
          %{
            street_1: "101 Reject St",
            street_2: nil,
            city: "Reject City",
            state: "RC",
            zip: "10101"
          }
        ],
        alternate_names: ["Jen Garcia", "Jenny Garcia", "Jenn Garcia"]
      })

      event = %LeadCreated{
        id: lead_id,
        user_id: user_id,
        timestamp: NaiveDateTime.utc_now(),
        # Not Jennifer or any variation
        first_name: "Amanda",
        # Different last name too
        last_name: "Smith",
        phone: phone,
        email: "amanda@example.com"
      }

      Oban.Testing.with_testing_mode(:manual, fn ->
        result = UnificationManager.handle(%UnificationManager{}, event)

        # Should schedule job and return []
        assert result == []

        # Verify UnificationJob was enqueued for non-matching names
        assert_enqueued(
          worker: UnificationJob,
          args: %{
            "contact_first_name" => "Amanda",
            "contact_last_name" => "Smith",
            "enrichment_first_name" => "Jennifer",
            "enrichment_last_name" => "Garcia",
            "enrichment_alternate_names" => ["Jen Garcia", "Jenny Garcia", "Jenn Garcia"]
          }
        )
      end)
    end

    test "does not schedule UnificationJob when Jaro matching succeeds" do
      lead_id = Ecto.UUID.generate()
      user_id = Ecto.UUID.generate()
      phone = "5551357924"
      enrichment_id = UUID.uuid5(:oid, phone)

      insert(:trestle, %{
        id: enrichment_id,
        first_name: "John",
        last_name: "Smith",
        addresses: [
          %{
            street_1: "111 Primary St",
            street_2: nil,
            city: "Primary City",
            state: "PC",
            zip: "11111"
          }
        ],
        alternate_names: ["Johnny Smith", "J Smith"]
      })

      event = %LeadCreated{
        id: lead_id,
        user_id: user_id,
        timestamp: NaiveDateTime.utc_now(),
        # Exact match - should not need job
        first_name: "John",
        last_name: "Smith",
        phone: phone,
        email: "john@example.com"
      }

      result = UnificationManager.handle(%UnificationManager{}, event)

      # Should return Unify command immediately (Jaro match)
      assert %Unify{} = result
      assert result.id == lead_id

      # Should NOT enqueue any jobs
      refute_enqueued(worker: UnificationJob)
    end

    test "unifies immediately when primary Jaro matches (Trestle-only data)" do
      lead_id = Ecto.UUID.generate()
      user_id = Ecto.UUID.generate()
      phone = "5559876543"
      enrichment_id = UUID.uuid5(:oid, phone)

      # Only create Trestle projection
      insert(:trestle, %{
        id: enrichment_id,
        first_name: "Jane",
        last_name: "Smith",
        addresses: [
          %{
            street_1: "456 Trestle Ave",
            street_2: nil,
            city: "Smith City",
            state: "SC",
            zip: "54321"
          }
        ],
        alternate_names: []
      })

      event = %LeadCreated{
        id: lead_id,
        user_id: user_id,
        timestamp: NaiveDateTime.utc_now(),
        # Different name - should schedule job
        first_name: "Janet",
        last_name: "Smith",
        phone: phone,
        email: "janet@example.com"
      }

      result = UnificationManager.handle(%UnificationManager{}, event)

      # Should unify immediately via primary Jaro ("Janet" vs "Jane" has high score)
      assert %Unify{} = result
      assert result.id == lead_id
      assert result.enrichment_id == enrichment_id
      # Should default enrichment type and Move Score when no Faraday
      assert result.enrichment_type == :lesser
      assert result.ptt == 0
      # Should use Trestle address data
      assert result.street_1 == "456 Trestle Ave"
      assert result.city == "Smith City"
      assert result.state == "SC"
      assert result.zip == "54321"
    end
  end

  describe "handle/2 - address selection" do
    test "prefers Faraday address when both Faraday and Trestle exist" do
      lead_id = Ecto.UUID.generate()
      user_id = Ecto.UUID.generate()
      phone = "5551234567"
      enrichment_id = UUID.uuid5(:oid, phone)

      insert(:faraday, %{
        id: enrichment_id,
        first_name: "John",
        last_name: "Doe",
        address: "123 Faraday St",
        city: "Faraday City",
        state: "FC",
        postcode: "12345",
        propensity_to_transact: 0.85,
        match_type: "address_full_name"
      })

      insert(:trestle, %{
        id: enrichment_id,
        first_name: "John",
        last_name: "Doe",
        addresses: [
          %{
            street_1: "999 Trestle St",
            street_2: "Apt 1",
            city: "Trestle City",
            state: "TC",
            zip: "99999"
          }
        ],
        alternate_names: []
      })

      event = %LeadCreated{
        id: lead_id,
        user_id: user_id,
        timestamp: NaiveDateTime.utc_now(),
        first_name: "John",
        last_name: "Doe",
        phone: phone,
        email: "john@example.com"
      }

      result = UnificationManager.handle(%UnificationManager{}, event)

      assert %Unify{} = result
      # Should use Faraday address
      assert result.street_1 == "123 Faraday St"
      assert result.street_2 == nil
      assert result.city == "Faraday City"
      assert result.state == "FC"
      assert result.zip == "12345"
    end

    test "uses first non-PO Box Trestle address when no Faraday exists" do
      lead_id = Ecto.UUID.generate()
      user_id = Ecto.UUID.generate()
      phone = "5552345678"
      enrichment_id = UUID.uuid5(:oid, phone)

      insert(:trestle, %{
        id: enrichment_id,
        first_name: "Jane",
        last_name: "Smith",
        addresses: [
          %{
            street_1: "PO Box 123",
            street_2: nil,
            city: "Mailbox City",
            state: "MC",
            zip: "11111"
          },
          %{
            street_1: "456 Real St",
            street_2: "Suite 200",
            city: "Real City",
            state: "RC",
            zip: "22222"
          }
        ],
        alternate_names: []
      })

      event = %LeadCreated{
        id: lead_id,
        user_id: user_id,
        timestamp: NaiveDateTime.utc_now(),
        first_name: "Jane",
        last_name: "Smith",
        phone: phone,
        email: "jane@example.com"
      }

      result = UnificationManager.handle(%UnificationManager{}, event)

      assert %Unify{} = result
      # Should skip PO Box and use second address
      assert result.street_1 == "456 Real St"
      assert result.street_2 == "Suite 200"
      assert result.city == "Real City"
      assert result.state == "RC"
      assert result.zip == "22222"
    end

    test "handles lowercase 'po box' pattern" do
      lead_id = Ecto.UUID.generate()
      user_id = Ecto.UUID.generate()
      phone = "5553456789"
      enrichment_id = UUID.uuid5(:oid, phone)

      insert(:trestle, %{
        id: enrichment_id,
        first_name: "Bob",
        last_name: "Jones",
        addresses: [
          %{
            street_1: "po box 456",
            street_2: nil,
            city: "Mail Town",
            state: "MT",
            zip: "33333"
          },
          %{
            street_1: "789 Home Ave",
            street_2: nil,
            city: "Home Town",
            state: "HT",
            zip: "44444"
          }
        ],
        alternate_names: []
      })

      event = %LeadCreated{
        id: lead_id,
        user_id: user_id,
        timestamp: NaiveDateTime.utc_now(),
        first_name: "Bob",
        last_name: "Jones",
        phone: phone,
        email: "bob@example.com"
      }

      result = UnificationManager.handle(%UnificationManager{}, event)

      assert %Unify{} = result
      assert result.street_1 == "789 Home Ave"
      assert result.city == "Home Town"
    end

    test "handles 'P.O. Box' pattern with periods" do
      lead_id = Ecto.UUID.generate()
      user_id = Ecto.UUID.generate()
      phone = "5554567890"
      enrichment_id = UUID.uuid5(:oid, phone)

      insert(:trestle, %{
        id: enrichment_id,
        first_name: "Alice",
        last_name: "Wonder",
        addresses: [
          %{
            street_1: "P.O. Box 789",
            street_2: nil,
            city: "Postal City",
            state: "PC",
            zip: "55555"
          },
          %{
            street_1: "321 Wonder Lane",
            street_2: nil,
            city: "Wonder City",
            state: "WC",
            zip: "66666"
          }
        ],
        alternate_names: []
      })

      event = %LeadCreated{
        id: lead_id,
        user_id: user_id,
        timestamp: NaiveDateTime.utc_now(),
        first_name: "Alice",
        last_name: "Wonder",
        phone: phone,
        email: "alice@example.com"
      }

      result = UnificationManager.handle(%UnificationManager{}, event)

      assert %Unify{} = result
      assert result.street_1 == "321 Wonder Lane"
      assert result.city == "Wonder City"
    end

    test "falls back to first Trestle address when all are PO Boxes" do
      lead_id = Ecto.UUID.generate()
      user_id = Ecto.UUID.generate()
      phone = "5555678901"
      enrichment_id = UUID.uuid5(:oid, phone)

      insert(:trestle, %{
        id: enrichment_id,
        first_name: "Charlie",
        last_name: "Brown",
        addresses: [
          %{
            street_1: "PO Box 111",
            street_2: nil,
            city: "First Mail",
            state: "FM",
            zip: "77777"
          },
          %{
            street_1: "P.O. Box 222",
            street_2: nil,
            city: "Second Mail",
            state: "SM",
            zip: "88888"
          }
        ],
        alternate_names: []
      })

      event = %LeadCreated{
        id: lead_id,
        user_id: user_id,
        timestamp: NaiveDateTime.utc_now(),
        first_name: "Charlie",
        last_name: "Brown",
        phone: phone,
        email: "charlie@example.com"
      }

      result = UnificationManager.handle(%UnificationManager{}, event)

      assert %Unify{} = result
      # Should fallback to first address since all are PO Boxes
      assert result.street_1 == "PO Box 111"
      assert result.city == "First Mail"
      assert result.state == "FM"
      assert result.zip == "77777"
    end

    test "uses Trestle address when Faraday has no address" do
      lead_id = Ecto.UUID.generate()
      user_id = Ecto.UUID.generate()
      phone = "5556789012"
      enrichment_id = UUID.uuid5(:oid, phone)

      insert(:faraday, %{
        id: enrichment_id,
        first_name: "Dave",
        last_name: "Miller",
        address: nil,
        city: nil,
        state: nil,
        postcode: nil,
        propensity_to_transact: 0.75,
        match_type: "phone_full_name"
      })

      insert(:trestle, %{
        id: enrichment_id,
        first_name: "Dave",
        last_name: "Miller",
        addresses: [
          %{
            street_1: "555 Trestle Blvd",
            street_2: nil,
            city: "Trestle Town",
            state: "TT",
            zip: "99999"
          }
        ],
        alternate_names: []
      })

      event = %LeadCreated{
        id: lead_id,
        user_id: user_id,
        timestamp: NaiveDateTime.utc_now(),
        first_name: "Dave",
        last_name: "Miller",
        phone: phone,
        email: "dave@example.com"
      }

      result = UnificationManager.handle(%UnificationManager{}, event)

      assert %Unify{} = result
      # Should fall back to Trestle since Faraday has no address
      assert result.street_1 == "555 Trestle Blvd"
      assert result.city == "Trestle Town"
      assert result.state == "TT"
      assert result.zip == "99999"
    end
  end
end
