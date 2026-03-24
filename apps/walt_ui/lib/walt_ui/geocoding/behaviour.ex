defmodule WaltUi.Geocoding.Behaviour do
  @moduledoc """
  Behaviour for geocoding services.
  """

  alias WaltUi.Projections.Contact

  @callback geocode_address(Contact.t()) :: {:ok, {float(), float()}} | {:error, atom()}
end
