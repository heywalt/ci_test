defmodule WaltUi.Geocoding.GeocodingCronJob do
  @moduledoc """
  Nightly cron job to ensure all premium users' contacts with addresses are geocoded.

  This is a safety net that catches any contacts missed due to:
  - Long enrichment queue delays
  - Race conditions during upgrades  
  - System issues during upgrade processing

  Runs nightly to guarantee 100% coverage for premium users.
  """

  use Oban.Worker, queue: :geocoding, max_attempts: 3

  require Logger

  alias WaltUi.Contacts
  alias WaltUi.Geocoding.GeocodeContactAddressJob

  @impl Oban.Worker
  def perform(_job) do
    Logger.metadata(module: __MODULE__)
    Logger.info("Starting nightly geocoding cleanup job")

    contacts_scheduled = process_geocodable_contacts()

    Logger.info("Nightly geocoding cleanup jobs scheduled",
      contacts_scheduled: contacts_scheduled
    )

    :ok
  end

  defp process_geocodable_contacts do
    Contacts.geocodable_contacts_for_all_premium_users_query()
    |> Repo.all()
    |> schedule_geocoding_jobs()
  end

  defp schedule_geocoding_jobs(contacts) do
    Enum.each(contacts, fn contact ->
      %{contact_id: contact.contact_id, user_id: contact.user_id}
      |> GeocodeContactAddressJob.new()
      |> Oban.insert()
    end)

    length(contacts)
  end
end
