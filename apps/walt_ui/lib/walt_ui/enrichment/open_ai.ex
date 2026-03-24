defmodule WaltUi.Enrichment.OpenAi do
  @moduledoc """
  Behaviour for OpenAi, defining the callbacks required to interact with the OpenAi API.
  """
  alias WaltUi.Projections.Contact

  @client Application.compile_env(:walt_ui, [:open_ai, :client], WaltUi.Enrichment.OpenAi.Client)

  @callback confirm_identity(map, map) :: {:ok, boolean} | {:error, map}
  @callback contact_matches_data(Contact.t(), any()) :: {:ok, boolean()} | {:error, map()}

  @spec contact_matches_data(Contact.t(), any()) :: {:ok, boolean()} | {:error, map()}
  def contact_matches_data(contact, data) do
    @client.contact_matches_data(contact, data)
  end

  @spec confirm_identity(map, map) :: {:ok, boolean} | {:error, map}
  def confirm_identity(possible_match, identity) do
    @client.confirm_identity(possible_match, identity)
  end
end
