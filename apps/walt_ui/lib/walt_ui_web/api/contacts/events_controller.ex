defmodule WaltUiWeb.Api.Contacts.EventsController do
  use WaltUiWeb, :controller

  alias WaltUi.Contacts
  alias WaltUiWeb.Authorization

  action_fallback WaltUiWeb.FallbackController

  def index(conn, %{"contact_id" => contact_id}) do
    current_user = conn.assigns.current_user

    with {:ok, contact} <- Contacts.fetch_contact(contact_id),
         {:ok, :authorized} <- Authorization.authorize(current_user, :view, contact) do
      conn
      |> put_view(WaltUiWeb.Api.Contacts.EventsView)
      |> render("show.json", %{data: contact.events})
    end
  end

  def create(conn, %{"contact_id" => contact_id} = params) do
    current_user = conn.assigns.current_user

    create_attrs = maybe_add_contact_id_to_note(params)

    with {:ok, contact} <- Contacts.fetch_contact(contact_id),
         {:ok, :authorized} <- Authorization.authorize(current_user, :edit, contact),
         {:ok, event} <- Contacts.create_event(create_attrs) do
      conn
      |> put_view(WaltUiWeb.Api.Contacts.EventsView)
      |> render("show.json", %{data: event})
    end
  end

  defp maybe_add_contact_id_to_note(%{"contact_id" => contact_id, "note" => _note} = params) do
    put_in(params, ["note", "contact_id"], contact_id)
  end

  defp maybe_add_contact_id_to_note(params) do
    params
  end
end
