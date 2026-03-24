defmodule WaltUi.Google.Maps.Client do
  @moduledoc """
  Context for interacting with Google Maps Geocoding API.
  """

  alias WaltUi.Directory
  alias WaltUi.Google.Maps.Http
  alias WaltUi.Projections.Contact

  def geocode_address(%Contact{} = contact) do
    case format_address(contact) do
      {:ok, address_string} -> Http.geocode_address(address_string)
      {:error, reason} -> {:error, reason}
    end
  end

  defp format_address(%Contact{} = contact) do
    street = Directory.house_number_and_street(contact)
    city = contact.city
    state = contact.state
    zip = contact.zip

    [street, city, state, zip]
    |> Enum.reject(fn part -> is_nil(part) or part == "" end)
    |> case do
      [] -> {:error, :no_address}
      parts -> {:ok, Enum.join(parts, ", ")}
    end
  end
end
