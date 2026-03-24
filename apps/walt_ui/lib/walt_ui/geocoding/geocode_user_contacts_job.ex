defmodule WaltUi.Geocoding.GeocodeUserContactsJob do
  @moduledoc """
  Background job to geocode all contacts for a user who has upgraded to premium.

  Handles both immediate geocoding (for contacts with existing addresses) and
  delayed geocoding (to catch in-flight enrichments that complete after upgrade).
  """

  use Oban.Pro.Worker, queue: :geocoding, max_attempts: 3

  require Logger
  import WaltUi.Guards

  alias WaltUi.Account
  alias WaltUi.Contacts
  alias WaltUi.Geocoding.GeocodeContactAddressJob

  # Define structured arguments schema
  args_schema do
    field :user_id, :string, required: true
    field :phase, :string, required: true
  end

  @impl Oban.Pro.Worker
  def process(%{args: %{user_id: user_id, phase: phase}}) do
    Logger.metadata(user_id: user_id, phase: phase, module: __MODULE__)

    case Account.get_user(user_id) do
      nil ->
        Logger.warning("User not found for geocoding job")
        :ok

      user when is_premium_user(user) ->
        geocode_user_contacts(user_id, phase)

      _user ->
        Logger.info("Skipping geocoding for non-premium user")
        :ok
    end
  end

  defp geocode_user_contacts(user_id, phase) do
    contacts_count =
      user_id
      |> Contacts.geocodable_contacts_query()
      |> Repo.all()
      |> schedule_individual_geocoding_jobs(user_id)

    Logger.info("Geocoding phase completed",
      phase: phase,
      user_id: user_id,
      contacts_scheduled: contacts_count
    )

    :ok
  end

  defp schedule_individual_geocoding_jobs(contacts, user_id) do
    contacts
    |> Enum.with_index()
    |> Enum.map(fn {contact, index} ->
      # Stagger jobs to respect rate limits
      schedule_in_seconds = index * 2

      %{contact_id: contact.id, user_id: user_id}
      |> GeocodeContactAddressJob.new(schedule_in: schedule_in_seconds)
      |> Oban.insert()
    end)
    |> length()
  end
end
