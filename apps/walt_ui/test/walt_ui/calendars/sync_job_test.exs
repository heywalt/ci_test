defmodule WaltUi.Calendars.SyncJobTest do
  use WaltUi.CqrsCase, async: false
  use Oban.Testing, repo: Repo

  import AssertAsync
  import WaltUi.Factory
  import Mox

  alias CQRS.Leads.Events
  alias WaltUi.Calendars.SyncJob
  alias WaltUi.Projections.ContactInteraction

  setup do
    Application.put_env(:tesla, :adapter, WaltUi.Google.CalendarMockAdapter)
    on_exit(fn -> Application.delete_env(:tesla, :adapter) end)

    start_supervised!(WaltUi.ProcessManagers.CalendarMeetingsManager)

    # Set up verify_on_exit! to make sure our mocks are called
    verify_on_exit!()

    user = insert(:user, email: "mike@heywalt.ai")
    ea = insert(:external_account, user: user, provider: :google)
    cal = insert(:calendar, user: user, source: :google, source_id: "my_main_calendar_google")

    [user: user, ea: ea, cal: cal]
  end

  describe "perform/1" do
    test "syncs events for all calendars that we have ane external account for", %{
      user: user,
      cal: cal
    } do
      contact = await_contact(user_id: user.id, email: "wade@deadpool.com")

      calendar_url = "https://www.googleapis.com/calendar/v3/calendars/#{cal.source_id}/events"

      Mox.expect(WaltUi.Google.CalendarMockAdapter, :call, fn env, _opts ->
        case env.url do
          "https://oauth2.googleapis.com/token" ->
            {:ok,
             %Tesla.Env{
               env
               | status: 200,
                 body: %{
                   "expires_in" => 3599,
                   "access_token" => "totally_legit_token_from_tesla_mock",
                   "refresh_token" => "totally_legit_refresh_token_from_tesla_mock"
                 }
             }}

          ^calendar_url ->
            {:ok,
             %Tesla.Env{
               env
               | status: 200,
                 body: %{
                   "items" => [
                     %{
                       "attendees" => [
                         %{
                           "email" => "mike@heywalt.ai",
                           "responseStatus" => "needsAction",
                           "self" => true
                         },
                         %{
                           "email" => "wade@deadpool.com",
                           "organizer" => true,
                           "responseStatus" => "accepted"
                         }
                       ],
                       "end" => %{
                         "dateTime" => "2025-02-04T13:00:00-07:00",
                         "timeZone" => "America/Denver"
                       },
                       "htmlLink" =>
                         "https://www.google.com/calendar/event?eid=MXI5NW1kZ3ZsZDExczRqMzdhZTEwaTA0aXNfMjAyNTAyMDRUMTkwMDAwWiBqZEBoZXl3YWx0LmFp",
                       "id" => "1r95mdgvld11s4j37ae10i04is_20250204T190000Z",
                       "kind" => "calendar#event",
                       "start" => %{
                         "dateTime" => "2025-02-04T12:00:00-07:00",
                         "timeZone" => "America/Denver"
                       },
                       "status" => "confirmed",
                       "summary" => "Lunch"
                     }
                   ]
                 }
             }}
        end
      end)

      :ok = perform_job(SyncJob, %{})

      assert_receive_event(
        CQRS,
        Events.ContactInvited,
        &(&1.id == contact.id)
      )

      assert_async do
        result = Repo.all(ContactInteraction)

        assert [%ContactInteraction{}] =
                 Enum.filter(result, fn ci -> ci.activity_type == :contact_invited end)
      end
    end

    test "syncs events for all calendars that we have ane external account for with contacts with multiple emails",
         %{
           user: user,
           cal: cal
         } do
      contact =
        await_contact(
          user_id: user.id,
          email: "me@deadpool.com",
          emails: [%{email: "wade@deadpool.com", label: "work"}]
        )

      calendar_url = "https://www.googleapis.com/calendar/v3/calendars/#{cal.source_id}/events"

      Mox.expect(WaltUi.Google.CalendarMockAdapter, :call, fn env, _opts ->
        case env.url do
          "https://oauth2.googleapis.com/token" ->
            {:ok,
             %Tesla.Env{
               env
               | status: 200,
                 body: %{
                   "expires_in" => 3599,
                   "access_token" => "totally_legit_token_from_tesla_mock",
                   "refresh_token" => "totally_legit_refresh_token_from_tesla_mock"
                 }
             }}

          ^calendar_url ->
            {:ok,
             %Tesla.Env{
               env
               | status: 200,
                 body: %{
                   "items" => [
                     %{
                       "attendees" => [
                         %{
                           "email" => "mike@heywalt.ai",
                           "responseStatus" => "needsAction",
                           "self" => true
                         },
                         %{
                           "email" => "wade@deadpool.com",
                           "organizer" => true,
                           "responseStatus" => "accepted"
                         }
                       ],
                       "end" => %{
                         "dateTime" => "2025-02-04T13:00:00-07:00",
                         "timeZone" => "America/Denver"
                       },
                       "htmlLink" =>
                         "https://www.google.com/calendar/event?eid=MXI5NW1kZ3ZsZDExczRqMzdhZTEwaTA0aXNfMjAyNTAyMDRUMTkwMDAwWiBqZEBoZXl3YWx0LmFp",
                       "id" => "1r95mdgvld11s4j37ae10i04is_20250204T190000Z",
                       "kind" => "calendar#event",
                       "start" => %{
                         "dateTime" => "2025-02-04T12:00:00-07:00",
                         "timeZone" => "America/Denver"
                       },
                       "status" => "confirmed",
                       "summary" => "Lunch"
                     }
                   ]
                 }
             }}
        end
      end)

      :ok = perform_job(SyncJob, %{})

      assert_receive_event(
        CQRS,
        Events.ContactInvited,
        &(&1.id == contact.id)
      )

      assert_async do
        result = Repo.all(ContactInteraction)

        assert [%ContactInteraction{}] =
                 Enum.filter(result, fn ci -> ci.activity_type == :contact_invited end)
      end
    end
  end
end
