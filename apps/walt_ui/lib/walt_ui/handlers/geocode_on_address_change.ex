defmodule WaltUi.Handlers.GeocodeOnAddressChange do
  @moduledoc """
  Event handler that triggers geocoding when contact address fields are updated.

  This handler listens for LeadUpdated events and schedules geocoding when:
  - Address fields (street_1, city, state, zip) are present in the update
  - The contact has a complete address suitable for geocoding

  Simple rule: if address changed, coordinates need updating.
  """

  use Commanded.Event.Handler,
    application: CQRS,
    name: __MODULE__

  require Logger
  import WaltUi.Guards

  alias CQRS.Leads.Events.LeadUnified
  alias CQRS.Leads.Events.LeadUpdated
  alias WaltUi.Account
  alias WaltUi.Contacts
  alias WaltUi.Geocoding.GeocodeContactAddressJob

  # Address fields that trigger geocoding when present in updates
  @address_fields ["street_1", "city", "state", "zip", :street_1, :city, :state, :zip]

  def handle(%LeadUpdated{} = event, _metadata) do
    Logger.metadata(contact_id: event.id, user_id: event.user_id, module: __MODULE__)

    if address_fields_updated?(event.attrs) do
      case Account.get_user(event.user_id) do
        user when is_premium_user(user) ->
          Logger.info(
            "Address fields updated in LeadUpdated, scheduling geocoding for premium user"
          )

          schedule_geocoding_for_contact(event.id)

        _ ->
          Logger.debug("Geocoding skipped for non-premium user on LeadUpdated",
            user_id: event.user_id
          )

          :ok
      end
    else
      :ok
    end
  end

  def handle(%LeadUnified{} = event, _metadata) do
    Logger.metadata(contact_id: event.id, enrichment_id: event.enrichment_id, module: __MODULE__)

    # Build address map from event to check if meaningful address data exists
    address_data = %{
      street_1: event.street_1,
      city: event.city,
      state: event.state,
      zip: event.zip
    }

    if has_geocodable_address?(address_data) do
      Logger.info("Address data present in LeadUnified, scheduling geocoding",
        enrichment_id: event.enrichment_id
      )

      # Use event data directly to avoid race condition with projection
      schedule_geocoding_with_event_data(event)
    else
      Logger.debug("No geocodable address in LeadUnified event, skipping")
      :ok
    end
  end

  defp schedule_geocoding_for_contact(contact_id) do
    case Contacts.get_contact(contact_id) do
      nil ->
        Logger.warning("Contact not found for geocoding", contact_id: contact_id)
        :ok

      contact ->
        maybe_schedule_geocoding(contact)
    end
  end

  defp address_fields_updated?(attrs) do
    attrs
    |> Map.keys()
    |> Enum.any?(&(&1 in @address_fields))
  end

  defp maybe_schedule_geocoding(contact) do
    if has_geocodable_address?(contact) do
      schedule_geocoding(contact)
    else
      Logger.debug("Skipping geocoding - incomplete address",
        contact_id: contact.id,
        street_1: present?(contact.street_1),
        city: present?(contact.city),
        zip: present?(contact.zip)
      )

      :ok
    end
  end

  defp has_geocodable_address?(address_data) do
    # Need at least street and city, or street and zip to geocode effectively
    has_street = present?(Map.get(address_data, :street_1))
    has_city = present?(Map.get(address_data, :city))
    has_zip = present?(Map.get(address_data, :zip))

    (has_street and has_city) or (has_street and has_zip)
  end

  defp present?(value) do
    not is_nil(value) and String.trim(value) != ""
  end

  defp schedule_geocoding(contact) do
    %{contact_id: contact.id, user_id: contact.user_id}
    |> GeocodeContactAddressJob.new()
    |> Oban.insert()

    Logger.info("Scheduled geocoding for address change",
      contact_id: contact.id,
      user_id: contact.user_id
    )

    :ok
  end

  defp schedule_geocoding_with_event_data(event) do
    # LeadUnified doesn't have user_id, so we need to fetch it from the contact
    # But we schedule with just contact_id and let the job fetch the user_id
    case Contacts.get_contact(event.id) do
      nil ->
        Logger.warning("Contact not found for geocoding", contact_id: event.id)
        :ok

      contact ->
        user = Account.get_user(contact.user_id)
        schedule_geocoding_for_user(user, event.id, contact.user_id)
    end
  end

  defp schedule_geocoding_for_user(user, contact_id, user_id) when is_premium_user(user) do
    %{contact_id: contact_id, user_id: user_id}
    |> GeocodeContactAddressJob.new()
    |> Oban.insert()

    Logger.info(
      "Scheduled geocoding for address change from LeadUnified for premium user",
      contact_id: contact_id,
      user_id: user_id
    )

    :ok
  end

  defp schedule_geocoding_for_user(_user, contact_id, user_id) do
    Logger.debug("Geocoding skipped for non-premium user on LeadUnified",
      contact_id: contact_id,
      user_id: user_id
    )

    :ok
  end
end
