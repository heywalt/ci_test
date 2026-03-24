defmodule WaltUi.Geocoding.GeocodeContactAddressJob do
  @moduledoc """
  Background job to geocode contact addresses using Google Maps API.
  Implements hybrid rate limiting (global + per-user) to respect API limits.
  """

  use Oban.Pro.Worker, queue: :geocoding, max_attempts: 10

  require Logger
  import WaltUi.Guards

  alias WaltUi.Account
  alias WaltUi.Contacts
  alias WaltUi.Geocoding
  alias WaltUi.Projections.Contact

  # Define structured arguments schema
  args_schema do
    field :contact_id, :string, required: true
    field :user_id, :string, required: true
  end

  @impl Oban.Pro.Worker
  def process(%{args: %{contact_id: contact_id, user_id: user_id}}) do
    Logger.metadata(contact_id: contact_id, user_id: user_id, module: __MODULE__)

    user = Account.get_user(user_id)
    process_for_user(user, contact_id, user_id)
  end

  defp process_for_user(user, contact_id, user_id) when is_premium_user(user) do
    with {:allow, _} <- check_global_rate_limit(),
         {:allow, _} <- check_user_rate_limit(user_id) do
      process_geocoding(contact_id)
    else
      {:deny, :global} ->
        Logger.info("Global rate limit exceeded, snoozing job")
        {:snooze, 1000}

      {:deny, :user} ->
        Logger.info("Per-user rate limit exceeded, snoozing job")
        {:snooze, 1000}
    end
  end

  defp process_for_user(_user, contact_id, user_id) do
    Logger.debug("Geocoding skipped for non-premium user in job",
      contact_id: contact_id,
      user_id: user_id
    )

    :ok
  end

  defp check_global_rate_limit do
    case Hammer.check_rate("geocoding:global", 1000, 45) do
      {:allow, count} -> {:allow, count}
      {:deny, _limit} -> {:deny, :global}
    end
  end

  defp check_user_rate_limit(user_id) do
    case Hammer.check_rate("geocoding:#{user_id}", 1000, 15) do
      {:allow, count} -> {:allow, count}
      {:deny, _limit} -> {:deny, :user}
    end
  end

  defp process_geocoding(contact_id) do
    case Repo.get(Contact, contact_id) do
      nil ->
        Logger.warning("Contact not found for geocoding")
        :ok

      contact ->
        geocode_and_update_contact(contact)
    end
  end

  defp geocode_and_update_contact(%Contact{} = contact) do
    case Geocoding.geocode_address(contact) do
      {:ok, {lat, lng}} ->
        update_contact_coordinates(contact, lat, lng)

      {:error, :no_address} ->
        Logger.info("Contact has no address to geocode")
        :ok

      {:error, :zero_results} ->
        Logger.info("No geocoding results found for contact address")
        :ok

      {:error, :rate_limit_exceeded} ->
        Logger.warning("Google Maps rate limit exceeded")
        {:snooze, 2000}

      {:error, :quota_exceeded} ->
        Logger.error("Google Maps quota exceeded")
        {:error, :quota_exceeded}

      {:error, reason} ->
        Logger.warning("Failed to geocode contact address", reason: reason)
        {:error, reason}
    end
  end

  defp update_contact_coordinates(%Contact{} = contact, lat, lng) do
    attrs = %{
      "latitude" => to_decimal(lat),
      "longitude" => to_decimal(lng)
    }

    case Contacts.update_contact(contact, attrs) do
      {:ok, _aggregate_state} ->
        Logger.info("Successfully geocoded contact address",
          contact_id: contact.id,
          latitude: lat,
          longitude: lng
        )

        :ok

      {:error, reason} ->
        Logger.error("Failed to update contact coordinates via CQRS",
          contact_id: contact.id,
          latitude: lat,
          longitude: lng,
          error: inspect(reason)
        )

        :ok
    end
  end

  defp to_decimal(value) when is_float(value) do
    value
    |> to_string()
    |> Decimal.new()
  end

  defp to_decimal(value) when is_integer(value) do
    Decimal.new(value)
  end

  defp to_decimal(%Decimal{} = value), do: value

  defp to_decimal(nil), do: nil
end
