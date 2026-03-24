defmodule WaltUiWeb.Api.Controllers.CalendarsControllerTest do
  use WaltUiWeb.ConnCase
  use Mimic

  import WaltUi.Factory

  alias WaltUi.Calendars
  alias WaltUi.Google.Calendars, as: Gcals

  setup :verify_on_exit!

  setup %{conn: conn} do
    {:ok, conn: put_req_header(conn, "accept", "application/json")}
  end

  describe "POST /api/calendar/:calendar_id/appointment" do
    setup do
      [user: insert(:user)]
    end

    test "creates a appointment and returns 204 NO CONTENT", %{user: user} = ctx do
      cal = insert(:calendar, user: user)
      _ea = insert(:external_account, user: user)

      start_time = DateTime.utc_now() |> DateTime.to_iso8601()
      end_time = DateTime.utc_now() |> DateTime.add(1, :hour) |> DateTime.to_iso8601()

      payload = %{
        start_time: start_time,
        end_time: end_time,
        title: "Super important meeting",
        provider: "google"
      }

      expect(Calendars, :create_appointment, fn _, _, _ -> {:ok, ""} end)

      assert ctx.conn
             |> authenticate_user(ctx.user)
             |> post(~p"/api/calendar/#{cal.id}/appointment", payload)
             |> response(204)
    end

    test "Returns 400 Bad Request is missing required field", %{user: user} = ctx do
      cal = insert(:calendar, user: user)
      _ea = insert(:external_account, user: user)

      start_time = DateTime.utc_now() |> DateTime.to_iso8601()
      end_time = DateTime.utc_now() |> DateTime.add(1, :hour) |> DateTime.to_iso8601()

      payload = %{
        start_time: start_time,
        end_time: end_time,
        title: "Super important meeting"
      }

      # Explicity expecting 0 calls
      reject(Calendars, :create_appointment, 3)

      assert ctx.conn
             |> authenticate_user(ctx.user)
             |> post(~p"/api/calendar/#{cal.id}/appointment", payload)
             |> json_response(400)
    end
  end

  describe "GET /api/calendar/events" do
    setup do
      # Mock Tesla to prevent HTTP requests during testing
      Tesla.Mock.mock_global(fn
        %{method: :get} ->
          %Tesla.Env{
            status: 200,
            body: %{
              "items" => []
            }
          }
      end)

      [user: insert(:user)]
    end

    test "returns todays events", %{user: user} = ctx do
      _ea = insert(:external_account, user: user, email: "jd@heywalt.ai")
      _cal = insert(:calendar, user: user, source_id: "jd@heywalt.ai", color: "#bada55")

      expect(Gcals, :get_todays_events, fn _, _ -> valid_events_from_google() end)

      assert response =
               ctx.conn
               |> authenticate_user(ctx.user)
               |> get(~p"/api/calendar/events", %{"timezone" => "America/Denver"})
               |> json_response(200)

      assert length(response) == 2

      Enum.map(response, fn event ->
        assert Map.has_key?(event, "attendee_contacts")
        assert Map.has_key?(event, "color")
      end)
    end
  end

  defp valid_events_from_google do
    [
      %{
        id: "_88q3gc1j6sojeb9g65334b9k8kq3cba26h0kab9l6d0jih1p70r3gci26k_20250605T150000Z",
        start: %{dateTime: "2025-06-05T09:00:00-06:00", timeZone: "America/Denver"},
        status: "confirmed",
        end: %{dateTime: "2025-06-05T09:30:00-06:00", timeZone: "America/Denver"},
        kind: "calendar#event",
        summary: "Stand Up",
        created: "2024-12-17T15:30:32.000Z",
        sequence: 0,
        attendees: [
          %{email: "jaxone@heywalt.ai", responseStatus: "accepted"},
          %{self: true, email: "jd@heywalt.ai", responseStatus: "accepted"},
          %{optional: true, email: "mikep@heywalt.ai", responseStatus: "accepted"},
          %{email: "johnson@heywalt.ai", responseStatus: "accepted"},
          %{email: "drew@heywalt.ai", responseStatus: "accepted"},
          %{email: "mike.peregrina@gmail.com", responseStatus: "accepted"}
        ],
        htmlLink:
          "https://www.google.com/calendar/event?eid=Xzg4cTNnYzFqNnNvamViOWc2NTMzNGI5azhrcTNjYmEyNmgwa2FiOWw2ZDBqaWgxcDcwcjNnY2kyNmtfMjAyNTA2MDVUMTUwMDAwWiBqZEBoZXl3YWx0LmFp",
        updated: "2025-06-03T14:16:55.357Z",
        etag: "\"3497920430714814\"",
        conferenceData: %{
          conferenceId: "ntf-zbne-rps",
          conferenceSolution: %{
            name: "Google Meet",
            key: %{type: "hangoutsMeet"},
            iconUri:
              "https://fonts.gstatic.com/s/i/productlogos/meet_2020q4/v6/web-512dp/logo_meet_2020q4_color_2x_web_512dp.png"
          },
          entryPoints: [
            %{
              label: "meet.google.com/ntf-zbne-rps",
              uri: "https://meet.google.com/ntf-zbne-rps",
              entryPointType: "video"
            }
          ]
        },
        creator: %{email: "mikep@heywalt.ai"},
        eventType: "default",
        hangoutLink: "https://meet.google.com/ntf-zbne-rps",
        iCalUID:
          "_88q3gc1j6sojeb9g65334b9k8kq3cba26h0kab9l6d0jih1p70r3gci26k_R20250114T160000@google.com",
        organizer: %{
          email:
            "c_7a9f0d5c38506ebd4b994b5f39dc29be5a25a6ebda062cf9e2456aa51ba4cdfa@group.calendar.google.com",
          displayName: "Product"
        },
        originalStartTime: %{
          dateTime: "2025-06-05T09:00:00-06:00",
          timeZone: "America/Denver"
        },
        recurringEventId:
          "_88q3gc1j6sojeb9g65334b9k8kq3cba26h0kab9l6d0jih1p70r3gci26k_R20250114T160000",
        reminders: %{useDefault: true}
      },
      %{
        id: "1r95mdgvld11s4j37ae10i04is_20250605T180000Z",
        start: %{dateTime: "2025-06-05T12:00:00-06:00", timeZone: "America/Denver"},
        status: "confirmed",
        end: %{dateTime: "2025-06-05T13:00:00-06:00", timeZone: "America/Denver"},
        kind: "calendar#event",
        summary: "Lunch",
        created: "2024-11-20T17:14:52.000Z",
        sequence: 0,
        htmlLink:
          "https://www.google.com/calendar/event?eid=MXI5NW1kZ3ZsZDExczRqMzdhZTEwaTA0aXNfMjAyNTA2MDVUMTgwMDAwWiBqZEBoZXl3YWx0LmFp",
        updated: "2024-11-20T17:14:52.078Z",
        etag: "\"3464245784156000\"",
        creator: %{self: true, email: "jd@heywalt.ai"},
        eventType: "default",
        iCalUID: "1r95mdgvld11s4j37ae10i04is@google.com",
        organizer: %{self: true, email: "jd@heywalt.ai"},
        originalStartTime: %{
          dateTime: "2025-06-05T12:00:00-06:00",
          timeZone: "America/Denver"
        },
        recurringEventId: "1r95mdgvld11s4j37ae10i04is",
        reminders: %{useDefault: true}
      }
    ]
  end
end
