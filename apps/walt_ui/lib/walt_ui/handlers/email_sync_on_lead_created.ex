defmodule WaltUi.Handlers.EmailSyncOnLeadCreated do
  @moduledoc false

  use Commanded.Event.Handler,
    application: CQRS,
    name: "email_sync_on_lead_created_handler"

  require Logger

  alias CQRS.Leads.Events.LeadCreated
  alias WaltUi.Email.SyncContactEmailsJob
  alias WaltUi.ExternalAccounts

  def handle(%LeadCreated{} = event, _metadata) do
    email_addresses = extract_email_addresses(event)

    if Enum.any?(email_addresses) do
      user_id = event.user_id

      case ExternalAccounts.for_user_id(user_id, :google) do
        nil ->
          Logger.debug("No Google external account found for user #{user_id}")
          :ok

        external_account ->
          Logger.info("Triggering email sync for user #{user_id} due to lead creation",
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
    |> SyncContactEmailsJob.new()
    |> Oban.insert()
    |> case do
      {:ok, _job} ->
        Logger.info("Successfully queued contact email sync job",
          external_account_id: external_account.id,
          email_addresses_count: length(email_addresses)
        )

        :ok

      {:error, reason} ->
        Logger.error("Failed to queue contact email sync job",
          external_account_id: external_account.id,
          email_addresses: email_addresses,
          error: inspect(reason)
        )

        {:error, reason}
    end
  end
end
