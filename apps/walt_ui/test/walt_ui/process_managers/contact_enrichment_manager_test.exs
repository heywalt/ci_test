defmodule WaltUi.ProcessManagers.ContactEnrichmentManagerTest do
  use WaltUi.CqrsCase
  use Oban.Testing, repo: Repo
  use Mimic

  import WaltUi.Factory

  alias CQRS.Enrichments.Events.EnrichmentComposed
  alias CQRS.Enrichments.Events.Jittered
  alias CQRS.Leads.Commands.Unify
  alias CQRS.Leads.Commands.Update
  alias WaltUi.Enrichment.UnificationJob
  alias WaltUi.ProcessManagers.ContactEnrichmentManager

  setup :verify_on_exit!

  describe "interested?/1 with EnrichmentComposed" do
    test "returns {:start, id} for EnrichmentComposed events" do
      event = %EnrichmentComposed{
        id: Ecto.UUID.generate(),
        composed_data: %{ptt: 85},
        data_sources: %{ptt: :faraday},
        provider_scores: %{faraday: 95},
        phone: "1234567890",
        timestamp: NaiveDateTime.utc_now(),
        alternate_names: []
      }

      assert ContactEnrichmentManager.interested?(event) == {:start, event.id}
    end

    test "returns false for other event types (unchanged behavior)" do
      other_event = %{id: Ecto.UUID.generate()}
      assert ContactEnrichmentManager.interested?(other_event) == false
    end
  end

  describe "handle/2 with EnrichmentComposed - high quality scores" do
    test "enqueues UnificationJob for high-quality enrichment with name mismatch" do
      Oban.Testing.with_testing_mode(:manual, fn ->
        user = insert(:user)

        contact =
          insert(:contact,
            user_id: user.id,
            enrichment_id: nil,
            standard_phone: "1234567890",
            first_name: "John",
            last_name: "Smith"
          )

        event = %EnrichmentComposed{
          id: Ecto.UUID.generate(),
          composed_data: %{
            # Different names that would require OpenAI verification
            first_name: "Robert",
            last_name: "Johnson",
            ptt: 85,
            city: "Austin",
            state: "TX",
            street_1: "123 Main St",
            street_2: "Apt 4B",
            zip: "78701"
          },
          data_sources: %{
            ptt: :faraday,
            city: :faraday,
            state: :trestle,
            street_1: :trestle,
            street_2: :trestle,
            zip: :trestle
          },
          # min = 90 (high quality)
          provider_scores: %{faraday: 95, trestle: 90},
          phone: "1234567890",
          timestamp: NaiveDateTime.utc_now(),
          alternate_names: []
        }

        commands = ContactEnrichmentManager.handle(%{id: event.id}, event)

        # Should return empty commands since job is enqueued asynchronously
        assert commands == []

        # Should enqueue UnificationJob
        assert_enqueued(
          worker: UnificationJob,
          args: %{
            contact_id: contact.id,
            contact_first_name: "John",
            contact_last_name: "Smith",
            enrichment_id: event.id,
            enrichment_first_name: "Robert",
            enrichment_last_name: "Johnson",
            enrichment_data: %{
              ptt: 85,
              city: "Austin",
              state: "TX",
              street_1: "123 Main St",
              street_2: "Apt 4B",
              zip: "78701"
            },
            enrichment_type: "best",
            user_id: user.id
          }
        )
      end)
    end

    test "enqueues UnificationJob for multiple contacts with high-quality enrichment" do
      Oban.Testing.with_testing_mode(:manual, fn ->
        user = insert(:user)

        contact1 =
          insert(:contact,
            user_id: user.id,
            enrichment_id: nil,
            standard_phone: "1234567890",
            first_name: "John",
            last_name: "Smith"
          )

        contact2 =
          insert(:contact,
            user_id: user.id,
            enrichment_id: nil,
            standard_phone: "1234567890",
            first_name: "Jane",
            last_name: "Smith"
          )

        event = %EnrichmentComposed{
          id: Ecto.UUID.generate(),
          composed_data: %{
            # Different names requiring OpenAI verification
            first_name: "Robert",
            last_name: "Johnson",
            ptt: 85
          },
          data_sources: %{ptt: :faraday},
          # min = 92 (high quality)
          provider_scores: %{faraday: 95, trestle: 92},
          phone: "1234567890",
          timestamp: NaiveDateTime.utc_now(),
          alternate_names: []
        }

        commands = ContactEnrichmentManager.handle(%{id: event.id}, event)

        # Should return empty commands since jobs are enqueued asynchronously
        assert commands == []

        # Should enqueue UnificationJob for both contacts
        assert_enqueued(
          worker: UnificationJob,
          args: %{
            contact_id: contact1.id,
            contact_first_name: "John",
            contact_last_name: "Smith",
            enrichment_id: event.id,
            enrichment_first_name: "Robert",
            enrichment_last_name: "Johnson",
            enrichment_data: %{ptt: 85},
            enrichment_type: "best",
            user_id: user.id
          }
        )

        assert_enqueued(
          worker: UnificationJob,
          args: %{
            contact_id: contact2.id,
            contact_first_name: "Jane",
            contact_last_name: "Smith",
            enrichment_id: event.id,
            enrichment_first_name: "Robert",
            enrichment_last_name: "Johnson",
            enrichment_data: %{ptt: 85},
            enrichment_type: "best",
            user_id: user.id
          }
        )
      end)
    end

    test "returns empty list when no phone matches found" do
      user = insert(:user)

      insert(:contact,
        user_id: user.id,
        enrichment_id: nil,
        # Different phone
        standard_phone: "9876543210"
      )

      event = %EnrichmentComposed{
        id: Ecto.UUID.generate(),
        composed_data: %{ptt: 85},
        data_sources: %{ptt: :faraday},
        provider_scores: %{faraday: 95, trestle: 90},
        phone: "1234567890",
        timestamp: NaiveDateTime.utc_now(),
        alternate_names: []
      }

      commands = ContactEnrichmentManager.handle(%{id: event.id}, event)

      assert commands == []
    end
  end

  describe "handle/2 with EnrichmentComposed - medium quality scores" do
    test "dispatches Unify when jaro distance > 0.70 for both names" do
      user = insert(:user)

      contact =
        insert(:contact,
          user_id: user.id,
          enrichment_id: nil,
          standard_phone: "1234567890",
          first_name: "John",
          last_name: "Smith"
        )

      event = %EnrichmentComposed{
        id: Ecto.UUID.generate(),
        composed_data: %{
          # Exact match
          first_name: "John",
          # Exact match
          last_name: "Smith",
          ptt: 75
        },
        data_sources: %{ptt: :faraday},
        # min = 80 < 90
        provider_scores: %{faraday: 80, trestle: 85},
        phone: "1234567890",
        timestamp: NaiveDateTime.utc_now(),
        alternate_names: []
      }

      commands = ContactEnrichmentManager.handle(%{id: event.id}, event)

      assert length(commands) == 1
      command = List.first(commands)
      assert %Unify{} = command
      assert command.id == contact.id
    end

    test "handles missing first_name or last_name in composed_data gracefully" do
      user = insert(:user)

      insert(:contact,
        user_id: user.id,
        enrichment_id: nil,
        standard_phone: "1234567890",
        first_name: "John",
        last_name: "Smith"
      )

      event = %EnrichmentComposed{
        id: Ecto.UUID.generate(),
        composed_data: %{
          # No first_name or last_name
          ptt: 75,
          city: "Austin"
        },
        data_sources: %{ptt: :faraday, city: :faraday},
        # min = 80 < 90
        provider_scores: %{faraday: 80, trestle: 85},
        phone: "1234567890",
        timestamp: NaiveDateTime.utc_now(),
        alternate_names: []
      }

      commands = ContactEnrichmentManager.handle(%{id: event.id}, event)

      # Should not dispatch without name data for low-quality enrichment
      assert commands == []
    end
  end

  describe "handle/2 with EnrichmentComposed - edge cases" do
    test "handles empty provider_scores map" do
      user = insert(:user)

      insert(:contact,
        user_id: user.id,
        enrichment_id: nil,
        standard_phone: "1234567890"
      )

      event = %EnrichmentComposed{
        id: Ecto.UUID.generate(),
        composed_data: %{ptt: 75},
        data_sources: %{ptt: :faraday},
        # Empty scores
        provider_scores: %{},
        phone: "1234567890",
        timestamp: NaiveDateTime.utc_now(),
        alternate_names: []
      }

      commands = ContactEnrichmentManager.handle(%{id: event.id}, event)

      # Should not dispatch with empty scores
      assert commands == []
    end

    test "handles missing first_name/last_name in composed_data" do
      user = insert(:user)

      insert(:contact,
        user_id: user.id,
        enrichment_id: nil,
        standard_phone: "1234567890"
      )

      event = %EnrichmentComposed{
        id: Ecto.UUID.generate(),
        # No name fields
        composed_data: %{ptt: 75},
        data_sources: %{ptt: :faraday},
        provider_scores: %{faraday: 80},
        phone: "1234567890",
        timestamp: NaiveDateTime.utc_now(),
        alternate_names: []
      }

      commands = ContactEnrichmentManager.handle(%{id: event.id}, event)

      # Should not dispatch without name data for medium quality
      assert commands == []
    end

    test "ignores contacts that already have enrichment_id" do
      user = insert(:user)

      insert(:contact,
        user_id: user.id,
        # Already has enrichment_id
        enrichment_id: Ecto.UUID.generate(),
        standard_phone: "1234567890"
      )

      event = %EnrichmentComposed{
        id: Ecto.UUID.generate(),
        composed_data: %{ptt: 85},
        data_sources: %{ptt: :faraday},
        provider_scores: %{faraday: 95, trestle: 90},
        phone: "1234567890",
        timestamp: NaiveDateTime.utc_now(),
        alternate_names: []
      }

      commands = ContactEnrichmentManager.handle(%{id: event.id}, event)

      # Should ignore contacts with existing enrichment_id
      assert commands == []
    end

    test "returns empty list when missing name data even with high quality scores" do
      # With new behavior, high quality scores still require name data
      user = insert(:user)

      insert(:contact,
        user_id: user.id,
        enrichment_id: nil,
        standard_phone: "1234567890"
      )

      event = %EnrichmentComposed{
        id: Ecto.UUID.generate(),
        # No name data
        composed_data: %{ptt: 85},
        data_sources: %{ptt: :faraday},
        provider_scores: %{faraday: 95, trestle: 90},
        phone: "1234567890",
        timestamp: NaiveDateTime.utc_now(),
        alternate_names: []
      }

      commands = ContactEnrichmentManager.handle(%{id: event.id}, event)

      # Should return empty list since name matching is required but no name data provided
      assert commands == []
    end
  end

  describe "handle/2 with EnrichmentComposed - linked contact updates" do
    test "dispatches Update for contact already linked to same enrichment_id" do
      user = insert(:user)
      enrichment_id = Ecto.UUID.generate()

      contact =
        insert(:contact,
          user_id: user.id,
          enrichment_id: enrichment_id,
          standard_phone: "1234567890",
          first_name: "John",
          last_name: "Smith"
        )

      event = %EnrichmentComposed{
        id: enrichment_id,
        composed_data: %{
          first_name: "John",
          last_name: "Smith",
          ptt: 85,
          city: "Austin",
          state: "TX",
          street_1: "123 Main St"
        },
        data_sources: %{ptt: :faraday, city: :faraday, state: :trestle, street_1: :trestle},
        provider_scores: %{faraday: 95, trestle: 90},
        phone: "1234567890",
        timestamp: NaiveDateTime.utc_now(),
        alternate_names: []
      }

      commands = ContactEnrichmentManager.handle(%{id: event.id}, event)

      assert length(commands) == 1
      command = List.first(commands)
      assert %Update{} = command
      assert command.id == contact.id
      assert command.user_id == user.id
      assert command.attrs.ptt == 85
      assert command.attrs.city == "Austin"
      assert command.attrs.state == "TX"
      assert command.attrs.street_1 == "123 Main St"
      assert command.attrs.enrichment_type == :best
    end

    test "still ignores contacts linked to different enrichment_id" do
      user = insert(:user)
      different_enrichment_id = Ecto.UUID.generate()

      insert(:contact,
        user_id: user.id,
        enrichment_id: different_enrichment_id,
        standard_phone: "1234567890",
        first_name: "John",
        last_name: "Smith"
      )

      event = %EnrichmentComposed{
        id: Ecto.UUID.generate(),
        composed_data: %{
          first_name: "John",
          last_name: "Smith",
          ptt: 85
        },
        data_sources: %{ptt: :faraday},
        provider_scores: %{faraday: 95, trestle: 90},
        phone: "1234567890",
        timestamp: NaiveDateTime.utc_now(),
        alternate_names: []
      }

      commands = ContactEnrichmentManager.handle(%{id: event.id}, event)

      assert commands == []
    end

    test "handles mix of linked and unlinked contacts for same phone" do
      user = insert(:user)
      enrichment_id = Ecto.UUID.generate()

      linked_contact =
        insert(:contact,
          user_id: user.id,
          enrichment_id: enrichment_id,
          standard_phone: "1234567890",
          first_name: "John",
          last_name: "Smith"
        )

      unlinked_contact =
        insert(:contact,
          user_id: user.id,
          enrichment_id: nil,
          standard_phone: "1234567890",
          first_name: "John",
          last_name: "Smith"
        )

      event = %EnrichmentComposed{
        id: enrichment_id,
        composed_data: %{
          first_name: "John",
          last_name: "Smith",
          ptt: 85
        },
        data_sources: %{ptt: :faraday},
        provider_scores: %{faraday: 50, trestle: 30},
        phone: "1234567890",
        timestamp: NaiveDateTime.utc_now(),
        alternate_names: []
      }

      commands = ContactEnrichmentManager.handle(%{id: event.id}, event)

      assert length(commands) == 2

      update_command = Enum.find(commands, &match?(%Update{}, &1))
      unify_command = Enum.find(commands, &match?(%Unify{}, &1))

      assert update_command.id == linked_contact.id
      assert update_command.attrs.enrichment_type == :lesser
      assert unify_command.id == unlinked_contact.id
      assert unify_command.enrichment_id == enrichment_id
    end
  end

  describe "handle/2 maintains existing behavior" do
    test "still handles Jittered events unchanged" do
      user = insert(:user)
      enrichment_id = Ecto.UUID.generate()

      insert(:contact,
        user_id: user.id,
        enrichment_id: enrichment_id
      )

      event = %Jittered{
        id: enrichment_id,
        score: 85,
        timestamp: NaiveDateTime.utc_now()
      }

      commands = ContactEnrichmentManager.handle(%{id: event.id}, event)

      assert length(commands) == 1
      command = List.first(commands)
      assert command.__struct__ == CQRS.Leads.Commands.JitterPtt
    end
  end

  describe "alternate names integration with enrichment flow" do
    test "complete flow: alternate name enables jaro match and dispatches Unify" do
      user = insert(:user)
      enrichment_id = Ecto.UUID.generate()

      # Create contact with name that doesn't match primary enrichment name
      contact =
        insert(:contact,
          user_id: user.id,
          enrichment_id: nil,
          standard_phone: "1234567890",
          # Contact name - low jaro vs "Alexander"
          first_name: "Bob",
          last_name: "Smith"
        )

      # Create Trestle projection with alternate names
      insert(:trestle,
        id: enrichment_id,
        # Primary enrichment name
        first_name: "Alexander",
        last_name: "Smith",
        alternate_names: ["Bob Smith", "Bobby Smith", "Robert Smith"]
      )

      # Create EnrichmentComposed event
      event = %EnrichmentComposed{
        id: enrichment_id,
        composed_data: %{
          # Would fail primary jaro vs "Bob"
          first_name: "Alexander",
          last_name: "Smith",
          ptt: 75
        },
        data_sources: %{ptt: :faraday},
        provider_scores: %{trestle: 80},
        phone: "1234567890",
        timestamp: NaiveDateTime.utc_now(),
        alternate_names: ["Bob Smith", "Bobby Smith", "Robert Smith"]
      }

      # Execute
      commands = ContactEnrichmentManager.handle(%{id: event.id}, event)

      # Assert: Should dispatch Unify (not enqueue UnificationJob)
      assert length(commands) == 1
      command = List.first(commands)
      assert %Unify{} = command
      assert command.id == contact.id
      assert command.enrichment_id == enrichment_id
    end

    test "complete flow: primary and alternate names both fail, falls back to UnificationJob" do
      # Setup: Contact name that matches neither primary nor alternate names
      user = insert(:user)
      enrichment_id = Ecto.UUID.generate()

      contact =
        insert(:contact,
          user_id: user.id,
          enrichment_id: nil,
          standard_phone: "1234567890",
          # No match with William or alternates
          first_name: "Robert",
          # Different last name too
          last_name: "Johnson"
        )

      insert(:trestle,
        id: enrichment_id,
        first_name: "William",
        last_name: "Smith",
        alternate_names: ["Bill Smith", "Will Smith"]
      )

      event = %EnrichmentComposed{
        id: enrichment_id,
        composed_data: %{
          first_name: "William",
          last_name: "Smith",
          ptt: 85
        },
        data_sources: %{ptt: :faraday},
        provider_scores: %{trestle: 95},
        phone: "1234567890",
        timestamp: NaiveDateTime.utc_now(),
        alternate_names: ["Bill Smith", "Will Smith"]
      }

      # Execute with manual Oban mode to check job args
      Oban.Testing.with_testing_mode(:manual, fn ->
        commands = ContactEnrichmentManager.handle(%{id: event.id}, event)

        # Assert: No immediate commands (job enqueued instead)
        assert commands == []

        # Assert: UnificationJob enqueued with alternate names
        assert_enqueued(
          worker: UnificationJob,
          args: %{
            contact_id: contact.id,
            enrichment_id: enrichment_id,
            enrichment_alternate_names: ["Bill Smith", "Will Smith"],
            contact_first_name: "Robert",
            contact_last_name: "Johnson",
            enrichment_first_name: "William",
            enrichment_last_name: "Smith",
            enrichment_data: %{ptt: 85},
            enrichment_type: "best",
            user_id: user.id
          }
        )
      end)
    end

    test "handles multiple contacts with different alternate name match results" do
      # Setup: Multiple contacts, some match alternates, some don't
      user = insert(:user)
      enrichment_id = Ecto.UUID.generate()

      # Contact 1: Matches via alternate name
      contact1 =
        insert(:contact,
          user_id: user.id,
          enrichment_id: nil,
          standard_phone: "1234567890",
          first_name: "Bill",
          last_name: "Smith"
        )

      # Contact 2: No match (will need UnificationJob)
      contact2 =
        insert(:contact,
          user_id: user.id,
          enrichment_id: nil,
          standard_phone: "1234567890",
          first_name: "Robert",
          last_name: "Johnson"
        )

      insert(:trestle,
        id: enrichment_id,
        first_name: "William",
        last_name: "Smith",
        alternate_names: ["Bill Smith", "Will Smith"]
      )

      event = %EnrichmentComposed{
        id: enrichment_id,
        composed_data: %{
          first_name: "William",
          last_name: "Smith",
          ptt: 85
        },
        data_sources: %{ptt: :faraday},
        provider_scores: %{trestle: 95},
        phone: "1234567890",
        timestamp: NaiveDateTime.utc_now(),
        alternate_names: ["Bill Smith", "Will Smith"]
      }

      Oban.Testing.with_testing_mode(:manual, fn ->
        commands = ContactEnrichmentManager.handle(%{id: event.id}, event)

        # Assert: One Unify command for contact1
        unify_commands = Enum.filter(commands, &match?(%Unify{}, &1))
        assert length(unify_commands) == 1
        assert List.first(unify_commands).id == contact1.id

        # Assert: One UnificationJob for contact2
        assert_enqueued(
          worker: UnificationJob,
          args: %{contact_id: contact2.id}
        )
      end)
    end
  end

  describe "alternate names edge cases in enrichment flow" do
    test "handles missing Trestle projection gracefully" do
      # Setup: Contact and event, but no Trestle projection exists
      user = insert(:user)
      enrichment_id = Ecto.UUID.generate()

      contact =
        insert(:contact,
          user_id: user.id,
          enrichment_id: nil,
          standard_phone: "1234567890",
          # Won't match "Alexander" via primary jaro
          first_name: "Robert",
          last_name: "Johnson"
        )

      # No Trestle projection created

      event = %EnrichmentComposed{
        id: enrichment_id,
        composed_data: %{
          # Low jaro vs "Robert"
          first_name: "Alexander",
          last_name: "Johnson",
          ptt: 85
        },
        data_sources: %{ptt: :faraday},
        # Non-trestle provider
        provider_scores: %{faraday: 95},
        phone: "1234567890",
        timestamp: NaiveDateTime.utc_now(),
        alternate_names: []
      }

      Oban.Testing.with_testing_mode(:manual, fn ->
        commands = ContactEnrichmentManager.handle(%{id: event.id}, event)

        # Assert: Falls back to UnificationJob with empty alternate names
        assert commands == []

        assert_enqueued(
          worker: UnificationJob,
          args: %{
            contact_id: contact.id,
            enrichment_alternate_names: []
          }
        )
      end)
    end

    test "handles empty alternate names array" do
      # Setup: Trestle projection exists but alternate_names is empty
      user = insert(:user)
      enrichment_id = Ecto.UUID.generate()

      contact =
        insert(:contact,
          user_id: user.id,
          enrichment_id: nil,
          standard_phone: "1234567890",
          # Won't match "Alexander" via primary jaro
          first_name: "Robert",
          last_name: "Johnson"
        )

      insert(:trestle,
        id: enrichment_id,
        first_name: "Alexander",
        last_name: "Johnson",
        # Empty array
        alternate_names: []
      )

      event = %EnrichmentComposed{
        id: enrichment_id,
        composed_data: %{
          # Low jaro vs "Robert"
          first_name: "Alexander",
          last_name: "Johnson",
          ptt: 85
        },
        data_sources: %{ptt: :faraday},
        provider_scores: %{trestle: 95},
        phone: "1234567890",
        timestamp: NaiveDateTime.utc_now(),
        alternate_names: []
      }

      Oban.Testing.with_testing_mode(:manual, fn ->
        commands = ContactEnrichmentManager.handle(%{id: event.id}, event)

        # Assert: Falls back to UnificationJob (no alternates to try)
        assert commands == []

        assert_enqueued(
          worker: UnificationJob,
          args: %{
            contact_id: contact.id,
            enrichment_alternate_names: []
          }
        )
      end)
    end

    test "handles malformed alternate names gracefully" do
      # Setup: Alternate names with various malformed entries
      user = insert(:user)
      enrichment_id = Ecto.UUID.generate()

      insert(:contact,
        user_id: user.id,
        enrichment_id: nil,
        standard_phone: "1234567890",
        first_name: "Bob",
        last_name: "Smith"
      )

      insert(:trestle,
        id: enrichment_id,
        first_name: "Alexander",
        last_name: "Smith",
        alternate_names: ["", "   ", "Bob Smith", "ValidName"]
      )

      event = %EnrichmentComposed{
        id: enrichment_id,
        composed_data: %{
          first_name: "Alexander",
          last_name: "Smith",
          ptt: 85
        },
        data_sources: %{ptt: :faraday},
        provider_scores: %{trestle: 95},
        phone: "1234567890",
        timestamp: NaiveDateTime.utc_now(),
        alternate_names: ["", "   ", "Bob Smith", "ValidName"]
      }

      commands = ContactEnrichmentManager.handle(%{id: event.id}, event)

      # Assert: Should still work (matching "Bob Smith")
      assert length(commands) == 1
      assert %Unify{} = List.first(commands)
    end
  end

  describe "alternate names backward compatibility" do
    test "existing behavior unchanged when no alternate names available" do
      # Setup: Traditional jaro matching scenario (no Trestle projection)
      user = insert(:user)
      enrichment_id = Ecto.UUID.generate()

      insert(:contact,
        user_id: user.id,
        enrichment_id: nil,
        standard_phone: "1234567890",
        # Exact match
        first_name: "John",
        last_name: "Smith"
      )

      event = %EnrichmentComposed{
        id: enrichment_id,
        composed_data: %{
          # Exact match
          first_name: "John",
          last_name: "Smith",
          ptt: 85
        },
        data_sources: %{ptt: :faraday},
        # Non-trestle provider
        provider_scores: %{faraday: 95},
        phone: "1234567890",
        timestamp: NaiveDateTime.utc_now(),
        alternate_names: []
      }

      commands = ContactEnrichmentManager.handle(%{id: event.id}, event)

      # Assert: Should work exactly as before (primary jaro match)
      assert length(commands) == 1
      assert %Unify{} = List.first(commands)
    end
  end

  describe "alternate names performance in enrichment flow" do
    test "performance remains acceptable with many alternate names" do
      # Setup: Large number of alternate names
      user = insert(:user)
      enrichment_id = Ecto.UUID.generate()

      insert(:contact,
        user_id: user.id,
        enrichment_id: nil,
        standard_phone: "1234567890",
        first_name: "Bob",
        last_name: "Smith"
      )

      # Create 50 alternate names (stress test)
      many_alternates = Enum.map(1..50, fn i -> "Alternate#{i} Smith" end)

      insert(:trestle,
        id: enrichment_id,
        first_name: "Alexander",
        last_name: "Smith",
        # Matching one at end
        alternate_names: many_alternates ++ ["Bob Smith"]
      )

      event = %EnrichmentComposed{
        id: enrichment_id,
        composed_data: %{
          first_name: "Alexander",
          last_name: "Smith",
          ptt: 85
        },
        data_sources: %{ptt: :faraday},
        provider_scores: %{trestle: 95},
        phone: "1234567890",
        timestamp: NaiveDateTime.utc_now(),
        alternate_names: many_alternates ++ ["Bob Smith"]
      }

      # Measure execution time
      {time_microseconds, commands} =
        :timer.tc(fn ->
          ContactEnrichmentManager.handle(%{id: event.id}, event)
        end)

      # Assert: Should still find match and reasonable performance
      assert length(commands) == 1
      assert %Unify{} = List.first(commands)

      # Assert: Performance should be reasonable (< 100ms)
      assert time_microseconds < 100_000
    end
  end
end
