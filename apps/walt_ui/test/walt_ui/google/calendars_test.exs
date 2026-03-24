defmodule WaltUi.Google.CalendarsTest do
  use WaltUi.CqrsCase
  import Mox

  import WaltUi.Factory

  alias WaltUi.Google.Calendars

  setup do
    Application.put_env(:tesla, :adapter, WaltUi.Google.CalendarMockAdapter)
    on_exit(fn -> Application.delete_env(:tesla, :adapter) end)

    user = insert(:user, email: "test@heywalt.ai")
    ea = insert(:external_account, user: user, provider: :google)
    cal = insert(:calendar, user: user, source: :google, source_id: "primary")

    [user: user, ea: ea, cal: cal]
  end

  setup :verify_on_exit!

  describe "get_calendars/1" do
    test "successfully fetches calendars list", %{ea: ea} do
      Mox.expect(WaltUi.Google.CalendarMockAdapter, :call, fn env, _opts ->
        assert env.url == "https://www.googleapis.com/calendar/v3/users/me/calendarList"
        {:ok, %Tesla.Env{env | status: 200, body: calendars_response()}}
      end)

      calendars = Calendars.get_calendars(ea)
      assert is_list(calendars)
      assert length(calendars) == 2

      [cal1, cal2] = calendars
      assert cal1.id == "primary"
      assert cal1.summary == "Test User's Calendar"
      assert cal2.id == "secondary@group.calendar.google.com"
      assert cal2.summary == "Secondary Calendar"
    end

    test "handles error response", %{ea: ea} do
      Mox.expect(WaltUi.Google.CalendarMockAdapter, :call, fn env, _opts ->
        assert env.url == "https://www.googleapis.com/calendar/v3/users/me/calendarList"
        {:ok, %Tesla.Env{env | status: 401, body: %{"error" => "Unauthorized"}}}
      end)

      result = Calendars.get_calendars(ea)
      assert result == []
    end
  end

  describe "get_events/3" do
    test "successfully fetches events for a calendar", %{ea: ea, cal: cal} do
      Mox.expect(WaltUi.Google.CalendarMockAdapter, :call, fn env, _opts ->
        assert String.contains?(env.url, "/calendars/#{cal.source_id}/events")
        assert Map.has_key?(env.query, :timeMin)
        assert Map.has_key?(env.query, :timeMax)
        {:ok, %Tesla.Env{env | status: 200, body: events_response()}}
      end)

      events = Calendars.get_events(ea, cal)
      assert is_list(events)
      assert length(events) == 1

      [event] = events
      assert event.id == "event123"
      assert event.summary == "Test Meeting"
      assert event.status == "confirmed"
      assert Map.has_key?(event, :start)
      assert Map.has_key?(event, :end)
    end

    test "successfully fetches events with custom days_ago", %{ea: ea, cal: cal} do
      Mox.expect(WaltUi.Google.CalendarMockAdapter, :call, fn env, _opts ->
        assert String.contains?(env.url, "/calendars/#{cal.source_id}/events")
        # Should have different timeMin when fetching for multiple days
        {:ok, %Tesla.Env{env | status: 200, body: events_response()}}
      end)

      events = Calendars.get_events(ea, cal, 30)
      assert is_list(events)
      assert length(events) == 1
    end

    test "handles error response", %{ea: ea, cal: cal} do
      Mox.expect(WaltUi.Google.CalendarMockAdapter, :call, fn env, _opts ->
        assert String.contains?(env.url, "/calendars/#{cal.source_id}/events")
        {:ok, %Tesla.Env{env | status: 404, body: %{"error" => "Calendar not found"}}}
      end)

      result = Calendars.get_events(ea, cal)
      assert result == []
    end
  end

  describe "create_calendars/2" do
    test "creates new calendars from API response", %{ea: ea} do
      calendar_attrs = [
        %{
          id: "calendar123",
          backgroundColor: "#bada55",
          summary: "New Calendar",
          timeZone: "America/Denver"
        }
      ]

      calendars = Calendars.create_calendars(calendar_attrs, ea)
      assert length(calendars) == 1
      [calendar] = calendars
      assert calendar.source_id == "calendar123"
      assert calendar.name == "New Calendar"
      assert calendar.timezone == "America/Denver"
    end

    test "updates existing calendars", %{ea: ea, cal: existing_cal} do
      calendar_attrs = [
        %{
          id: existing_cal.source_id,
          backgroundColor: "#bada55",
          summary: "Updated Calendar Name",
          timeZone: "America/New_York"
        }
      ]

      calendars = Calendars.create_calendars(calendar_attrs, ea)
      assert length(calendars) == 1
      [calendar] = calendars
      assert calendar.id == existing_cal.id
      assert calendar.name == "Updated Calendar Name"
      assert calendar.timezone == "America/New_York"
    end

    test "filters out holiday calendars", %{ea: ea} do
      calendar_attrs = [
        %{
          id: "en.usa#holiday@group.v.calendar.google.com",
          summary: "US Holidays",
          timeZone: "America/Los_Angeles"
        }
      ]

      calendars = Calendars.create_calendars(calendar_attrs, ea)
      assert calendars == []
    end
  end

  describe "get_and_create_meetings/3" do
    test "fetches events and creates meetings", %{ea: ea, cal: cal} do
      # Mock the get_events function
      Mox.expect(WaltUi.Google.CalendarMockAdapter, :call, fn env, _opts ->
        assert String.contains?(env.url, "/calendars/#{cal.source_id}/events")
        {:ok, %Tesla.Env{env | status: 200, body: events_response()}}
      end)

      results = Calendars.get_and_create_meetings(cal, ea)
      assert is_list(results)
      assert length(results) == 1

      [{:ok, meeting}] = results
      assert meeting.name == "Test Meeting"
      assert meeting.calendar_id == cal.id
      assert meeting.user_id == ea.user_id
    end

    test "fetches events and creates meetings with all day event", %{ea: ea, cal: cal} do
      # Mock the get_events function
      Mox.expect(WaltUi.Google.CalendarMockAdapter, :call, fn env, _opts ->
        assert String.contains?(env.url, "/calendars/#{cal.source_id}/events")
        {:ok, %Tesla.Env{env | status: 200, body: all_day_event_response()}}
      end)

      results = Calendars.get_and_create_meetings(cal, ea)
      assert is_list(results)
      assert length(results) == 1

      [{:ok, meeting}] = results
      assert meeting.name == "This is an all day event for testing reasons"
      assert meeting.calendar_id == cal.id
      assert meeting.user_id == ea.user_id
    end
  end

  describe "create_appointment/3" do
    test "successfully creates a calendar appointment", %{ea: ea, cal: cal} do
      appointment_attrs = %{
        start_time: "2024-03-30T09:00:00-06:00",
        end_time: "2024-03-30T10:00:00-06:00",
        title: "Important Meeting"
      }

      Mox.expect(WaltUi.Google.CalendarMockAdapter, :call, fn env, _opts ->
        assert env.method == :post
        assert String.contains?(env.url, "/calendars/#{cal.source_id}/events")

        {:ok,
         %Tesla.Env{
           env
           | status: 200,
             body: %{
               "id" => "new_event_id",
               "htmlLink" => "https://calendar.google.com/event?id=123",
               "creator" => %{"email" => "test@heywalt.ai"},
               "summary" => "Important Meeting"
             }
         }}
      end)

      {:ok, %{body: body}} = Calendars.create_appointment(ea, cal, appointment_attrs)
      assert body["id"] == "new_event_id"
      assert body["summary"] == "Important Meeting"
    end

    test "handles error when creating appointment", %{ea: ea, cal: cal} do
      appointment_attrs = %{
        start_time: "2024-03-30T09:00:00-06:00",
        end_time: "2024-03-30T10:00:00-06:00",
        title: "Important Meeting"
      }

      Mox.expect(WaltUi.Google.CalendarMockAdapter, :call, fn env, _opts ->
        assert env.method == :post
        assert String.contains?(env.url, "/calendars/#{cal.source_id}/events")
        {:ok, %Tesla.Env{env | status: 400, body: %{"error" => "Invalid request"}}}
      end)

      result = Calendars.create_appointment(ea, cal, appointment_attrs)
      assert {:error, _} = result
    end
  end

  describe "initial_sync/1" do
    test "syncs calendars and events on initial setup", %{ea: ea} do
      # Mock calendar list
      Mox.expect(WaltUi.Google.CalendarMockAdapter, :call, fn env, _opts ->
        assert env.url == "https://www.googleapis.com/calendar/v3/users/me/calendarList"
        {:ok, %Tesla.Env{env | status: 200, body: calendars_response()}}
      end)

      Mox.expect(WaltUi.Google.CalendarMockAdapter, :call, 2, fn env, _opts ->
        assert String.contains?(env.url, "/events")
        {:ok, %Tesla.Env{env | status: 200, body: events_response()}}
      end)

      results = Calendars.initial_sync(ea)
      assert is_list(results)
      # Should return a list of {:ok, meeting} tuples
      assert Enum.all?(results, fn result -> match?({:ok, _}, result) end)
    end

    test "syncs calendars and events with all day event and creates a meeting", %{ea: ea} do
      # Mock calendar list
      Mox.expect(WaltUi.Google.CalendarMockAdapter, :call, fn env, _opts ->
        assert env.url == "https://www.googleapis.com/calendar/v3/users/me/calendarList"
        {:ok, %Tesla.Env{env | status: 200, body: calendars_response()}}
      end)

      Mox.expect(WaltUi.Google.CalendarMockAdapter, :call, 2, fn env, _opts ->
        assert String.contains?(env.url, "/events")
        {:ok, %Tesla.Env{env | status: 200, body: all_day_event_response()}}
      end)

      results = Calendars.initial_sync(ea)
      assert is_list(results)
      # Should return a list of {:ok, meeting} tuples
      assert Enum.all?(results, fn result -> match?({:ok, _}, result) end)
    end
  end

  defp calendars_response do
    %{
      "items" => [
        %{
          "id" => "primary",
          "summary" => "Test User's Calendar",
          "timeZone" => "America/Denver",
          "backgroundColor" => "#bada55"
        },
        %{
          "id" => "secondary@group.calendar.google.com",
          "summary" => "Secondary Calendar",
          "timeZone" => "America/Los_Angeles",
          "backgroundColor" => "#bada55"
        }
      ]
    }
  end

  defp events_response do
    %{
      "items" => [
        %{
          "id" => "event123",
          "summary" => "Test Meeting",
          "status" => "confirmed",
          "htmlLink" => "https://calendar.google.com/event?id=123",
          "start" => %{
            "dateTime" => "2024-03-20T10:00:00-06:00",
            "timeZone" => "America/Denver"
          },
          "end" => %{
            "dateTime" => "2024-03-20T11:00:00-06:00",
            "timeZone" => "America/Denver"
          },
          "kind" => "calendar#event",
          "attendees" => [
            %{
              "email" => "test@heywalt.ai",
              "self" => true,
              "responseStatus" => "accepted"
            },
            %{
              "email" => "attendee@example.com",
              "responseStatus" => "accepted"
            }
          ]
        }
      ]
    }
  end

  defp all_day_event_response do
    %{
      "items" => [
        %{
          "id" => "4r14ftkq04ofm0o48bb7amf2ac",
          "start" => %{
            "date" => "2025-03-18"
          },
          "status" => "confirmed",
          "end" => %{
            "date" => "2026-03-19"
          },
          "kind" => "calendar#event",
          "summary" => "This is an all day event for testing reasons",
          "created" => "2025-03-19T18:38:29.000Z",
          "sequence" => 0,
          "attendees" => [
            %{
              "self" => true,
              "email" => "jd@heywalt.ai",
              "organizer" => true,
              "responseStatus" => "accepted"
            },
            %{
              "email" => "johnson@heywalt.ai",
              "responseStatus" => "needsAction"
            }
          ],
          "htmlLink" =>
            "https://www.google.com/calendar/event?eid=NHIxNGZ0a3EwNG9mbTBvNDhiYjdhbWYyYWMgamRAaGV5d2FsdC5haQ",
          "etag" => "\"3484819020505374\"",
          "creator" => %{self: true, email: "jd@heywalt.ai"},
          "organizer" => %{self: true, email: "jd@heywalt.ai"},
          "eventType" => "default",
          "iCalUID" => "4r14ftkq04ofm0o48bb7amf2ac@google.com",
          "reminders" => %{useDefault: false},
          "transparency" => "transparent",
          "updated" => "2025-03-19T18:38:30.252Z"
        }
      ]
    }
  end
end
