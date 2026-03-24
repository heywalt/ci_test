defmodule WaltUiWeb.Api.NotesController do
  use WaltUiWeb, :controller

  alias WaltUi.Directory
  alias WaltUi.Directory.Note
  alias WaltUiWeb.Authorization

  action_fallback WaltUiWeb.FallbackController

  def index(conn, _params) do
    current_user = conn.assigns.current_user

    with {:ok, :authorized} <- Authorization.authorize(current_user, :view, :notes),
         {:ok, notes} <- {:ok, Directory.list_users_contacts_notes(current_user.id)} do
      conn
      |> put_view(WaltUiWeb.Api.Contacts.NotesView)
      |> render("show.json", %{data: notes})
    end
  end

  def show(conn, %{"id" => id}) do
    current_user = conn.assigns.current_user

    with {:ok, note} <- Directory.fetch_note(id),
         {:ok, :authorized} <- Authorization.authorize(current_user, :view, note) do
      conn
      |> put_view(WaltUiWeb.Api.Contacts.NotesView)
      |> render("show.json", %{data: note})
    end
  end

  def update(conn, %{"id" => id, "note" => note_attrs}) do
    current_user = conn.assigns.current_user

    with {:ok, note} <- Directory.fetch_note(id),
         {:ok, :authorized} <- Authorization.authorize(current_user, :update, note),
         {:ok, %Note{} = note} <- Directory.update_note(note, note_attrs) do
      conn
      |> put_view(WaltUiWeb.Api.Contacts.NotesView)
      |> render("show.json", %{data: note})
    end
  end
end
