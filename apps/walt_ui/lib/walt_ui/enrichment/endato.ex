defmodule WaltUi.Enrichment.Endato do
  @moduledoc """
  Behaviour for Endato, defining the callbacks required to interact with the Endato API.
  """

  alias WaltUi.Projections.Contact
  alias WaltUi.Providers.Endato

  @callback fetch_contact(map | Contact.t() | Endato.t()) :: {:ok, map()} | {:error, String.t()}
  @callback search_by_phone(String.t()) :: {:ok, map()} | {:error, String.t()}

  @spec fetch_contact(map | Contact.t() | Endato.t()) :: {:ok, map()} | {:error, String.t()}
  def fetch_contact(contact) do
    client().fetch_contact(contact)
  end

  @spec search_by_phone(String.t()) :: {:ok, map()} | {:error, String.t()}
  def search_by_phone(phone) do
    client().search_by_phone(phone)
  end

  defp client do
    Application.get_env(:walt_ui, WaltUi.Endato)[:client] || WaltUi.Enrichment.Endato.Client
  end
end
