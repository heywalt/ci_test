defmodule WaltUi.Handlers.CalendarSyncOnLeadCreated do
  @moduledoc false

  use Commanded.Event.Handler,
    application: CQRS,
    name: "calendar_sync_on_lead_created_handler",
    start_from: :current

  require Logger

  alias CQRS.Leads.Events.LeadCreated
  alias WaltUi.Calendars.SyncContactCalendarEventsJob
  alias WaltUi.ExternalAccounts

  def handle(%LeadCreated{} = event, _metadata) do
    email_addresses = extract_email_addresses(event)

    if Enum.any?(email_addresses) do
      user_id = event.user_id

      case ExternalAccounts.for_user_id(user_id, :google) do
        nil ->
          Logger.debug("No Google external account found for user #{user_id}")

        external_account ->
          Logger.info("Triggering calendar sync for user #{user_id} due to lead creation",
            email_addresses: email_addresses
          )

          enqueue_sync_job(external_account, email_addresses)
      end
    else
      :ok
    end
  end

  defp extract_email_addresses(event) do
    email = event.email
    emails = event.emails || []

    embedded_emails =
      Enum.map(emails, fn
        %{"email" => email_addr} -> email_addr
        %{email: email_addr} -> email_addr
        _ -> nil
      end)

    ([email] ++ embedded_emails)
    |> Enum.reject(&is_nil/1)
    |> Enum.uniq()
  end

  defp enqueue_sync_job(external_account, email_addresses) do
    %{
      external_account_id: external_account.id,
      email_addresses: email_addresses
    }
    |> SyncContactCalendarEventsJob.new()
    |> Oban.insert()
    |> case do
      {:ok, _job} ->
        Logger.info("Successfully queued contact calendar sync job",
          external_account_id: external_account.id,
          email_addresses_count: length(email_addresses)
        )

      {:error, reason} ->
        Logger.error("Failed to queue contact calendar sync job",
          external_account_id: external_account.id,
          email_addresses: email_addresses,
          error: inspect(reason)
        )
    end
  end
end
