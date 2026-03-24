defmodule WaltUi.Calendars.SyncContactCalendarEventsJob do
  @moduledoc """
  Oban job to sync calendar events for specific email addresses on contact updates.
  Fetches calendar events where the specified email addresses are attendees and
  dispatches InviteContact commands directly, bypassing the MeetingAggregate.
  """
  use Oban.Worker,
    queue: :contact_calendar_sync,
    max_attempts: 3,
    priority: 3

  require Logger

  alias CQRS.Leads.Commands.InviteContact
  alias WaltUi.Contacts
  alias WaltUi.ExternalAccounts
  alias WaltUi.Google.Calendars, as: Gcals

  @impl Oban.Worker
  def perform(%Oban.Job{
        args: %{"external_account_id" => ea_id, "email_addresses" => email_addresses}
      }) do
    Logger.info("Starting calendar sync for contact",
      external_account_id: ea_id,
      email_addresses_count: length(email_addresses)
    )

    result =
      with {:ok, external_account} <- fetch_external_account(ea_id),
           :ok <- validate_google_account(external_account),
           :ok <- process_calendar_sync(external_account, email_addresses) do
        :ok
      else
        {:error, reason} -> {:error, reason}
      end

    case result do
      :ok ->
        Logger.info("Completed calendar sync successfully",
          external_account_id: ea_id,
          email_addresses_count: length(email_addresses)
        )

      {:error, reason} ->
        Logger.error("Calendar sync failed",
          external_account_id: ea_id,
          email_addresses_count: length(email_addresses),
          error: inspect(reason)
        )
    end

    result
  end

  # Catch-all for debugging
  def perform(%Oban.Job{args: args} = job) do
    Logger.error("SyncContactCalendarEventsJob called with unexpected args structure",
      args: inspect(args),
      job: inspect(job)
    )

    {:error, "Unexpected args structure"}
  end

  defp fetch_external_account(ea_id) do
    case ExternalAccounts.get(ea_id) do
      nil -> {:error, "External account not found"}
      external_account -> {:ok, external_account}
    end
  end

  defp validate_google_account(%{provider: :google}), do: :ok
  defp validate_google_account(_), do: {:error, :not_google}

  defp process_calendar_sync(_external_account, []), do: :ok

  defp process_calendar_sync(external_account, email_addresses) do
    case Gcals.get_events_by_attendee_emails_all_calendars(external_account, email_addresses) do
      {:ok, calendar_events} ->
        Logger.info("Found calendar events for sync",
          external_account_id: external_account.id,
          calendar_events_count: length(calendar_events)
        )

        try do
          dispatch_invite_commands(calendar_events, external_account.user_id, email_addresses)
          :ok
        rescue
          exception ->
            Logger.error("Exception in dispatch_invite_commands",
              exception: inspect(exception),
              stacktrace: Exception.format_stacktrace(__STACKTRACE__)
            )

            {:error, "Exception in dispatch_invite_commands: #{inspect(exception)}"}
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp dispatch_invite_commands(calendar_events, user_id, contact_email_addresses) do
    Enum.each(calendar_events, fn event ->
      dispatch_event_invites(event, user_id, contact_email_addresses)
    end)
  end

  defp dispatch_event_invites(event, user_id, contact_email_addresses) do
    relevant_attendee_emails =
      event.attendees
      |> Enum.map(& &1.email)
      |> Enum.filter(&(&1 in contact_email_addresses))

    contact_ids = find_contact_ids(user_id, relevant_attendee_emails)

    Enum.each(contact_ids, fn contact_id ->
      dispatch_invite_for_contact(event, user_id, contact_id, relevant_attendee_emails)
    end)
  end

  defp find_contact_ids(_user_id, []), do: []

  defp find_contact_ids(user_id, relevant_attendee_emails) do
    user_id
    |> Contacts.get_contacts_by_emails(relevant_attendee_emails)
    |> Map.values()
    |> List.flatten()
    |> Enum.uniq()
  end

  defp dispatch_invite_for_contact(event, user_id, contact_id, relevant_attendee_emails) do
    attendee_status = find_attendee_status(event, relevant_attendee_emails)

    build_invite_command_map(event, user_id, contact_id, attendee_status)
    |> InviteContact.new()
    |> CQRS.dispatch()
  end

  defp find_attendee_status(event, relevant_attendee_emails) do
    case Enum.find(event.attendees, &(&1.email in relevant_attendee_emails)) do
      %{responseStatus: status} -> status
      _ -> nil
    end
  end

  defp build_invite_command_map(event, user_id, contact_id, attendee_status) do
    %{
      id: contact_id,
      user_id: user_id,
      name: Map.get(event, :summary, "Untitled Event"),
      start_time: event.start_time,
      end_time: event.end_time,
      source_id: event.id,
      location: Map.get(event, :location),
      link: Map.get(event, :hangoutLink),
      calendar_id: event.calendar_id,
      kind: Map.get(event, :kind),
      meeting_id: event.id,
      status: attendee_status
    }
  end
end
