defmodule WaltUi.Calendars.SyncContactCalendarEventsJobTest do
  use WaltUi.CqrsCase, async: false
  use Mimic
  use Oban.Testing, repo: Repo

  import WaltUi.Helpers
  import WaltUi.Factory
  import AssertAsync

  alias WaltUi.Calendars.SyncContactCalendarEventsJob
  alias WaltUi.Google.Calendars

  setup :verify_on_exit!

  describe "perform/1" do
    test "dispatches InviteContact commands for calendar events with matching attendees" do
      user = insert(:user)

      # Create contact through CQRS so it exists in projections
      contact =
        await_contact(%{
          user_id: user.id,
          email: "test@example.com"
        })

      # Create real external account in database
      external_account =
        insert(:external_account, %{
          provider: :google,
          email: "user@example.com",
          user: user
        })

      email_addresses = ["test@example.com"]

      calendar_events = [
        %{
          id: "event_123",
          summary: "Test Meeting",
          start_time: ~N[2024-01-15 10:00:00],
          end_time: ~N[2024-01-15 11:00:00],
          attendees: [
            %{email: "test@example.com", responseStatus: "accepted"},
            %{email: "user@example.com", responseStatus: "accepted"}
          ],
          source_id: "google_event_123",
          location: "Conference Room A",
          link: "https://meet.google.com/abc-def-ghi",
          calendar_id: Ecto.UUID.generate(),
          kind: "calendar#event"
        }
      ]

      # Only mock the calendar API and CQRS dispatch
      expect(Calendars, :get_events_by_attendee_emails_all_calendars, fn ea, ^email_addresses ->
        assert ea.id == external_account.id
        {:ok, calendar_events}
      end)

      # Don't mock CQRS.dispatch - let it actually run and verify the results

      job_args = %{
        "external_account_id" => external_account.id,
        "email_addresses" => email_addresses
      }

      job = %Oban.Job{args: job_args}

      assert :ok = SyncContactCalendarEventsJob.perform(job)

      # Verify that ContactInvited event was created and contact interaction was projected
      assert_async do
        interactions = WaltUi.ContactInteractions.for_contact(contact.id)

        meeting_interactions =
          Enum.filter(interactions, &(&1.activity_type == :contact_invited))

        assert length(meeting_interactions) == 1

        interaction = List.first(meeting_interactions)
        assert interaction.metadata["name"] == "Test Meeting"
        assert interaction.occurred_at == ~N[2024-01-15 10:00:00]
      end
    end

    test "handles external account not found" do
      non_existent_id = Ecto.UUID.generate()

      job_args = %{
        "external_account_id" => non_existent_id,
        "email_addresses" => ["test@example.com"]
      }

      job = %Oban.Job{args: job_args}

      assert {:error, "External account not found"} = SyncContactCalendarEventsJob.perform(job)
    end

    test "handles non-Google external account" do
      external_account =
        insert(:external_account, %{
          provider: :skyslope,
          email: "user@example.com"
        })

      job_args = %{
        "external_account_id" => external_account.id,
        "email_addresses" => ["test@example.com"]
      }

      job = %Oban.Job{args: job_args}

      assert {:error, :not_google} = SyncContactCalendarEventsJob.perform(job)
    end

    test "handles empty email addresses list" do
      external_account =
        insert(:external_account, %{
          provider: :google,
          email: "user@example.com"
        })

      job_args = %{
        "external_account_id" => external_account.id,
        "email_addresses" => []
      }

      job = %Oban.Job{args: job_args}

      assert :ok = SyncContactCalendarEventsJob.perform(job)
    end

    test "handles calendar events with no matching contacts" do
      user = insert(:user)

      external_account =
        insert(:external_account, %{
          provider: :google,
          email: "user@example.com",
          user: user
        })

      email_addresses = ["nonexistent@example.com"]

      calendar_events = [
        %{
          id: "event_123",
          summary: "Test Meeting",
          attendees: [%{email: "nonexistent@example.com"}],
          kind: "calendar#event"
        }
      ]

      expect(Calendars, :get_events_by_attendee_emails_all_calendars, fn ea, emails ->
        assert ea.id == external_account.id
        assert emails == email_addresses
        {:ok, calendar_events}
      end)

      job_args = %{
        "external_account_id" => external_account.id,
        "email_addresses" => email_addresses
      }

      job = %Oban.Job{args: job_args}

      assert :ok = SyncContactCalendarEventsJob.perform(job)
    end

    test "handles calendar API errors" do
      external_account =
        insert(:external_account, %{
          provider: :google,
          email: "user@example.com"
        })

      email_addresses = ["test@example.com"]

      expect(Calendars, :get_events_by_attendee_emails_all_calendars, fn ea, emails ->
        assert ea.id == external_account.id
        assert emails == email_addresses
        {:error, "Calendar API error"}
      end)

      job_args = %{
        "external_account_id" => external_account.id,
        "email_addresses" => email_addresses
      }

      job = %Oban.Job{args: job_args}

      assert {:error, "Calendar API error"} = SyncContactCalendarEventsJob.perform(job)
    end

    test "handles calendar events without summary field" do
      user = insert(:user)

      # Create contact through CQRS so it exists in projections
      contact =
        await_contact(%{
          user_id: user.id,
          email: "test@example.com"
        })

      # Create real external account in database
      external_account =
        insert(:external_account, %{
          provider: :google,
          email: "user@example.com",
          user: user
        })

      email_addresses = ["test@example.com"]

      # Event without summary field (which causes the KeyError)
      calendar_events = [
        %{
          id: "event_no_summary",
          # Note: no summary field
          start_time: ~N[2024-01-15 10:00:00],
          end_time: ~N[2024-01-15 11:00:00],
          attendees: [
            %{email: "test@example.com", responseStatus: "accepted"}
          ],
          source_id: "google_event_no_summary",
          calendar_id: Ecto.UUID.generate()
          # Note: no kind field either
        }
      ]

      expect(Calendars, :get_events_by_attendee_emails_all_calendars, fn ea, ^email_addresses ->
        assert ea.id == external_account.id
        {:ok, calendar_events}
      end)

      job_args = %{
        "external_account_id" => external_account.id,
        "email_addresses" => email_addresses
      }

      job = %Oban.Job{args: job_args}

      # Should not crash and should complete successfully
      assert :ok = SyncContactCalendarEventsJob.perform(job)

      # Verify that ContactInvited event was created with "Untitled Event" as name
      assert_async do
        interactions = WaltUi.ContactInteractions.for_contact(contact.id)

        meeting_interactions =
          Enum.filter(interactions, &(&1.activity_type == :contact_invited))

        assert length(meeting_interactions) == 1

        interaction = List.first(meeting_interactions)
        assert interaction.metadata["name"] == "Untitled Event"
        assert interaction.occurred_at == ~N[2024-01-15 10:00:00]
      end
    end
  end
end
