defmodule WaltUiWeb.Api.Contacts.NotesController do
  use WaltUiWeb, :controller

  alias WaltUi.Contacts
  alias WaltUi.Directory
  alias WaltUiWeb.Authorization

  action_fallback WaltUiWeb.FallbackController

  def index(conn, %{"contact_id" => contact_id}) do
    current_user = conn.assigns.current_user

    with {:ok, contact} <- Contacts.fetch_contact(contact_id),
         {:ok, :authorized} <- Authorization.authorize(current_user, :view, contact) do
      conn
      |> put_view(WaltUiWeb.Api.Contacts.NotesView)
      |> render("show.json", %{data: contact.notes})
    end
  end

  def create(conn, %{"contact_id" => contact_id, "note" => note}) do
    current_user = conn.assigns.current_user

    with {:ok, contact} <- Contacts.fetch_contact(contact_id),
         {:ok, :authorized} <- Authorization.authorize(current_user, :create, :notes),
         {:ok, note} <- Directory.create_note(%{note: note, contact_id: contact.id}) do
      conn
      |> put_view(WaltUiWeb.Api.Contacts.NotesView)
      |> render("show.json", %{data: note})
    end
  end
end
