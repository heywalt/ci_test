defmodule WaltUi.Geocoding do
  @moduledoc """
  Service module for geocoding addresses to coordinates.
  """

  @behaviour WaltUi.Geocoding.Behaviour

  alias WaltUi.Google.Maps.Client
  alias WaltUi.Projections.Contact

  @impl true
  def geocode_address(%Contact{} = contact) do
    Client.geocode_address(contact)
  end
end
