defmodule WaltUi.Google.Calendars do
  @moduledoc """
  Client for interacting with Google Calendar API.
  """

  require Logger

  alias CQRS.Utils
  alias WaltUi.Calendars
  alias WaltUi.Calendars.Calendar
  alias WaltUi.ExternalAccounts.ExternalAccount
  alias WaltUi.ExternalAccountsAuthHelper, as: Auth

  @spec initial_sync(ExternalAccount.t()) :: [{:ok, map} | {:error, term}]
  def initial_sync(ea) do
    ea
    |> get_calendars()
    |> create_calendars(ea)
    |> Enum.flat_map(fn cal -> get_and_create_meetings(cal, ea, 30) end)
  end

  @spec sync_events_for_external_account(ExternalAccount.t()) :: [{:ok, map} | {:error, term}]
  def sync_events_for_external_account(ea) do
    Enum.map(ea.user.calendars, fn cal ->
      get_and_create_meetings(cal, ea)
    end)
  end

  @spec get_calendars(ExternalAccount.t()) :: [map]
  def get_calendars(external_account) do
    with {:ok, token} <- Auth.get_latest_token(external_account) do
      token
      |> client()
      |> Tesla.get("/users/me/calendarList")
      |> handle_response()
    end
  end

  @spec get_events(ExternalAccount.t(), Calendar.t(), integer) :: [map]
  def get_events(external_account, calendar, days_ago \\ 1) do
    # Note: This can be confusing; if we run this at 1am ET, we will get
    # the current datetime in UTC (which will be the current day), and
    # subtract 1 from it to get us "yesterday"; in the request_events/4
    # function, we'll get the end of that day, and get all events up
    # until that point in time.
    end_date = DateTime.utc_now() |> Timex.shift(days: -1)

    with {:ok, token} <- Auth.get_latest_token(external_account) do
      case days_ago do
        1 ->
          request_events(token, calendar, end_date, end_date)

        _ ->
          start_date = Timex.shift(end_date, days: -days_ago)
          request_events(token, calendar, start_date, end_date)
      end
    end
  end

  def get_calendar(external_account, calendar_id) do
    with {:ok, token} <- Auth.get_latest_token(external_account) do
      token
      |> client()
      |> Tesla.get("/calendars/#{calendar_id}")
      |> handle_response()
    end
  end

  @spec get_todays_events(ExternalAccount.t(), String.t()) :: [map]
  def get_todays_events(external_account, timezone) do
    today = DateTime.utc_now() |> DateTime.shift_zone!(timezone)

    with {:ok, token} <- Auth.get_latest_token(external_account) do
      request_primary_calendar_events(token, today, today)
    end
  end

  @spec get_events_by_attendee_emails(ExternalAccount.t(), [String.t()]) ::
          {:ok, [map]} | {:error, term}
  def get_events_by_attendee_emails(external_account, email_addresses) do
    with {:ok, token} <- Auth.get_latest_token(external_account) do
      {:ok, request_events_by_attendee_emails(token, email_addresses)}
    end
  end

  @spec get_events_by_attendee_emails_all_calendars(ExternalAccount.t(), [String.t()]) ::
          {:ok, [map]} | {:error, term}
  def get_events_by_attendee_emails_all_calendars(external_account, email_addresses) do
    with {:ok, _token} <- Auth.get_latest_token(external_account) do
      events =
        external_account
        |> get_calendars()
        |> create_calendars(external_account)
        |> Enum.flat_map(fn cal ->
          get_events_with_attendee_filter(cal, external_account, email_addresses)
        end)

      {:ok, events}
    end
  end

  @spec create_calendars([map], ExternalAccount.t()) :: [Calendar.t()]
  def create_calendars(calendar_attrs, ea) do
    calendar_attrs
    |> Enum.reject(fn %{id: id} -> id == "en.usa#holiday@group.v.calendar.google.com" end)
    |> Enum.map(fn cal ->
      case Calendars.for_user_id_and_source(ea.user_id, :google, cal.id) do
        nil ->
          Calendars.create!(cal, ea.user_id, :google)

        existing_cal ->
          Calendars.update!(existing_cal, cal)
      end
    end)
  end

  def get_and_create_meetings(cal, ea, days_ago \\ 1) do
    ea
    |> get_events(cal, days_ago)
    |> Enum.map(fn event -> Map.merge(event, %{user_id: ea.user_id, calendar_id: cal.id}) end)
    |> Enum.map(fn event ->
      Map.merge(event, %{
        start_time: get_start_time(event.start),
        end_time: get_end_time(event.end)
      })
    end)
    |> Enum.map(&CQRS.create_meeting/1)
  end

  def get_events_with_attendee_filter(cal, ea, email_addresses) do
    ea
    |> get_events_filtered_by_attendees(cal, email_addresses)
    |> Enum.map(fn event -> Map.merge(event, %{user_id: ea.user_id, calendar_id: cal.id}) end)
    |> Enum.map(fn event ->
      Map.merge(event, %{
        start_time: get_start_time(event.start),
        end_time: get_end_time(event.end)
      })
    end)
  end

  @spec create_appointment(ExternalAccount.t(), Calendar.t(), map) :: {:ok, map} | []
  def create_appointment(ea, calendar, attrs) do
    with {:ok, token} <- Auth.get_latest_token(ea) do
      formatted_attrs = format_attrs(attrs)

      token
      |> client()
      |> Tesla.post("/calendars/#{calendar.source_id}/events", formatted_attrs)
      |> handle_create_response()
    end
  end

  defp config do
    Application.get_env(:walt_ui, __MODULE__)
  end

  defp client(access_token) do
    middleware = [
      {Tesla.Middleware.BaseUrl, config()[:base_url]},
      Tesla.Middleware.JSON,
      {Tesla.Middleware.BearerAuth, token: access_token}
    ]

    adapter = Application.get_env(:tesla, :adapter, Tesla.Adapter.Hackney)

    Tesla.client(middleware, adapter)
  end

  defp handle_response({:ok, %{status: code, body: body}}) when code in 200..299 do
    if body == nil do
      Logger.warning("Empty response from Google")
      []
    else
      body
      |> Utils.atom_map()
      |> then(fn %{items: items} -> items end)
    end
  end

  defp handle_response({:ok, %{status: code}}) when code == 404 do
    Logger.warning("Calendar not found in Google.")

    []
  end

  defp handle_response({:ok, %{status: code}}) when code == 401 do
    Logger.warning("Unauthorized request to Google.")

    []
  end

  defp handle_response({:ok, response}) do
    Logger.warning("Unexpected Response from Google", details: inspect(response))

    []
  end

  defp handle_response({:error, response}) do
    Logger.warning("Unexpected Error Response from Google", details: inspect(response))

    []
  end

  defp handle_create_response({:ok, %{status: code} = response}) when code in 200..299 do
    %{"creator" => %{"email" => email}} = response.body

    Logger.info("Event created by: #{email}")

    {:ok, response}
  end

  defp handle_create_response({:ok, response}) do
    Logger.warning("Unexpected Response from Google", details: inspect(response))

    {:error, response}
  end

  defp handle_create_response({:error, response}) do
    Logger.warning("Unexpected Error Response from Google", details: inspect(response))

    {:error, response}
  end

  defp request_events(token, calendar, start_date, end_date) do
    params = %{
      timeMin: start_date |> Timex.beginning_of_day() |> Timex.format!("{RFC3339}"),
      timeMax: end_date |> Timex.end_of_day() |> Timex.format!("{RFC3339}"),
      singleEvents: true,
      orderBy: "startTime"
    }

    token
    |> client()
    |> Tesla.get("/calendars/#{calendar.source_id}/events", query: params)
    |> handle_response()
  end

  defp request_primary_calendar_events(token, start_date, end_date) do
    params = %{
      timeMin: start_date |> Timex.beginning_of_day() |> Timex.format!("{RFC3339}"),
      timeMax: end_date |> Timex.end_of_day() |> Timex.format!("{RFC3339}"),
      singleEvents: true,
      orderBy: "startTime"
    }

    token
    |> client()
    |> Tesla.get("/calendars/primary/events", query: params)
    |> handle_response()
  end

  defp request_events_by_attendee_emails(token, email_addresses) do
    # Build query to search for events where any of the email addresses are attendees
    # Similar to Gmail sync, we'll search within a configurable timeframe
    days_back = Application.get_env(:walt_ui, :calendar_sync_days_back, 180)
    end_date = DateTime.utc_now()
    start_date = DateTime.add(end_date, -days_back, :day)

    params = %{
      timeMin: start_date |> Timex.format!("{RFC3339}"),
      timeMax: end_date |> Timex.format!("{RFC3339}"),
      singleEvents: true,
      orderBy: "startTime"
    }

    # Query primary calendar for events within the timeframe
    events =
      token
      |> client()
      |> Tesla.get("/calendars/primary/events", query: params)
      |> handle_response()

    # Filter events to only include those where attendees contain any of the email addresses
    Enum.filter(events, fn event ->
      case Map.get(event, :attendees) do
        nil ->
          false

        attendees when is_list(attendees) ->
          attendee_emails = Enum.map(attendees, & &1[:email])
          Enum.any?(email_addresses, &(&1 in attendee_emails))

        _ ->
          false
      end
    end)
  end

  defp get_events_filtered_by_attendees(external_account, calendar, email_addresses) do
    days_back = Application.get_env(:walt_ui, :calendar_sync_days_back, 180)
    end_date = DateTime.utc_now()
    start_date = DateTime.add(end_date, -days_back, :day)

    with {:ok, token} <- Auth.get_latest_token(external_account) do
      params = %{
        timeMin: start_date |> Timex.format!("{RFC3339}"),
        timeMax: end_date |> Timex.format!("{RFC3339}"),
        singleEvents: true,
        orderBy: "startTime"
      }

      events =
        token
        |> client()
        |> Tesla.get("/calendars/#{calendar.source_id}/events", query: params)
        |> handle_response()

      # Filter events to only include those where attendees contain any of the email addresses
      Enum.filter(events, fn event ->
        case Map.get(event, :attendees) do
          nil ->
            false

          attendees when is_list(attendees) ->
            attendee_emails = Enum.map(attendees, & &1[:email])
            Enum.any?(email_addresses, &(&1 in attendee_emails))

          _ ->
            false
        end
      end)
    end
  end

  defp format_attrs(attrs) do
    attrs
    |> Map.merge(%{
      start: %{dateTime: attrs.start_time},
      end: %{dateTime: attrs.end_time},
      summary: attrs.title
    })
    |> Map.drop([:calendar_id, :end_time, :start_time])
  end

  defp get_start_time(%{date: date}) do
    date
    |> Timex.parse!("{YYYY}-{0M}-{0D}")
    |> Timex.beginning_of_day()
  end

  defp get_start_time(%{dateTime: date_time}) do
    NaiveDateTime.from_iso8601!(date_time)
  end

  defp get_end_time(%{date: date}) do
    date
    |> Timex.parse!("{YYYY}-{0M}-{0D}")
    |> Timex.end_of_day()
  end

  defp get_end_time(%{dateTime: date_time}) do
    NaiveDateTime.from_iso8601!(date_time)
  end
end
