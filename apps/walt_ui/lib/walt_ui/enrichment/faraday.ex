defmodule WaltUi.Enrichment.Faraday do
  @moduledoc """
  Behaviour for Faraday, defining the callbacks required to interact with the Faraday API.
  """

  alias WaltUi.Projections.Contact
  alias WaltUi.Providers.Endato

  @callback fetch_by_identity_sets([map]) :: {:ok, map} | {:error, String.t()}
  @callback fetch_contact(Contact.t() | Endato.t()) :: {:ok, map()} | {:error, String.t()}
  @callback extract_ptt(map()) :: {:ok, String.t()} | {:error, atom()}

  @spec fetch_by_identity_sets([map]) :: {:ok, map} | {:error, String.t()}
  def fetch_by_identity_sets(id_sets) do
    client().fetch_by_identity_sets(id_sets)
  end

  @spec fetch_contact(Contact.t() | Endato.t()) :: {:ok, map()} | {:error, String.t()}
  def fetch_contact(contact) do
    client().fetch_contact(contact)
  end

  @spec extract_ptt(map()) :: {:ok, String.t()} | {:error, atom()}
  def extract_ptt(response) do
    client().extract_ptt(response)
  end

  defp client do
    Application.get_env(:walt_ui, WaltUi.Faraday)[:client] || WaltUi.Enrichment.Faraday.Client
  end
end
