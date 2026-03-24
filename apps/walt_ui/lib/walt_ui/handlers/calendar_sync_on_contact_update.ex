defmodule WaltUi.Handlers.CalendarSyncOnContactUpdate do
  @moduledoc false

  use Commanded.Event.Handler,
    application: CQRS,
    name: "calendar_sync_on_contact_update_handler",
    start_from: :current

  require Logger

  alias CQRS.Leads.Events.LeadUpdated
  alias WaltUi.Calendars.SyncContactCalendarEventsJob
  alias WaltUi.ExternalAccounts

  def handle(%LeadUpdated{} = event, _metadata) do
    if email_changed?(event.metadata) do
      user_id = event.user_id

      case ExternalAccounts.for_user_id(user_id, :google) do
        nil ->
          Logger.debug("No Google external account found for user #{user_id}")

        external_account ->
          email_addresses = extract_email_addresses(event.attrs)

          Logger.info("Triggering calendar sync for user #{user_id} due to contact email change",
            user_id: user_id,
            contact_id: event.id,
            email_addresses: email_addresses
          )

          enqueue_sync_job(external_account, email_addresses)
      end
    else
      :ok
    end
  end

  defp email_changed?(metadata) do
    Enum.any?(metadata, fn
      %{"field" => field} -> field in ["email", :email, "emails", :emails]
      %{field: field} -> field in ["email", :email, "emails", :emails]
      _ -> false
    end)
  end

  defp extract_email_addresses(attrs) do
    email = Map.get(attrs, :email) || Map.get(attrs, "email")
    emails = Map.get(attrs, :emails) || Map.get(attrs, "emails")

    embedded_emails =
      case emails do
        emails when is_list(emails) ->
          Enum.map(emails, fn
            %{"email" => email_addr} -> email_addr
            %{email: email_addr} -> email_addr
            _ -> nil
          end)

        _ ->
          []
      end

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
