defmodule WaltUiWeb.Api.Contacts.AddressController do
  use WaltUiWeb, :controller

  import CozyParams
  import Ecto.Query

  alias WaltUi.Contacts
  alias WaltUi.Projections
  alias WaltUiWeb.Authorization

  action_fallback WaltUiWeb.FallbackController

  def index(conn, %{"contact_id" => contact_id}) do
    current_user = conn.assigns.current_user

    with {:ok, contact} <- Contacts.fetch_contact(contact_id),
         {:ok, :authorized} <- Authorization.authorize(current_user, :view, contact) do
      contact_id
      |> Contacts.get_possible_addresses()
      |> then(&json(conn, %{data: &1}))
    end
  end

  def update(conn, %{"contact_id" => contact_id, "id" => addr_id}) do
    current_user = conn.assigns.current_user

    with {:ok, %{contact: contact, address: addr}} <-
           get_contact_and_address(contact_id, addr_id),
         {:ok, :authorized} <- Authorization.authorize(current_user, :view, contact),
         :ok <- CQRS.select_address(contact_id, addr) do
      send_resp(conn, :no_content, "")
    end
  end

  defparams :create_params do
    field :street_1, :string, required: true
    field :street_2, :string, default: ""
    field :city, :string, required: true
    field :state, :string, required: true
    field :zip, :string, required: true
  end

  def create(conn, %{"contact_id" => contact_id} = params) do
    current_user = conn.assigns.current_user

    with {:ok, addr} <- create_params(params),
         {:ok, contact} <- Contacts.fetch_contact(contact_id),
         {:ok, :authorized} <- Authorization.authorize(current_user, :view, contact),
         :ok <- CQRS.select_address(contact_id, addr) do
      send_resp(conn, :no_content, "")
    end
  end

  defp get_contact_and_address(contact_id, addr_id) do
    case Repo.one(
           from con in Projections.Contact,
             inner_join: addr in Projections.PossibleAddress,
             on: addr.enrichment_id == con.enrichment_id,
             where: con.id == ^contact_id,
             where: addr.id == ^addr_id,
             select: %{
               contact: con,
               address: addr
             }
         ) do
      nil -> {:error, :not_found}
      map -> {:ok, map}
    end
  end
end
