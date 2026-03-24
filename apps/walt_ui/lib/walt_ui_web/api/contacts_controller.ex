defmodule WaltUiWeb.Api.ContactsController do
  use WaltUiWeb, :controller

  import CozyParams

  require Logger

  alias WaltUi.Contacts
  alias WaltUi.Projections.Contact
  alias WaltUiWeb.Authorization

  action_fallback WaltUiWeb.FallbackController

  @doc """
  List all contacts for the current user.

  This bypasses the pagination system and returns all contacts for the user,
  which is wy the page_number, and total_pages are hard-coded.

  This is done so that the mobile app can make a request to a paginated list of
  contacts and have something to display initially and then request the full list
  so that the whole list of contacts can be available for searching and filtering
  on device.
  """
  def index(conn, %{"page" => "all"}) do
    current_user = conn.assigns.current_user
    contacts = Contacts.list_contacts_by_user(current_user.id)

    conn
    |> put_view(WaltUiWeb.Api.ContactsView)
    |> render(:show, %{
      data: contacts,
      paginate: %{
        page_number: 1,
        page_size: length(contacts),
        total_pages: 1
      }
    })
  end

  def index(conn, %{"hidden" => "true"} = params) do
    current_user = conn.assigns.current_user
    pagination_opts = get_pagination_opts(params)

    page =
      current_user.id
      |> Contacts.hidden_contacts_by_user_query()
      |> Contacts.preload_common_associations()
      |> Contacts.paginate(pagination_opts)

    conn
    |> put_view(WaltUiWeb.Api.ContactsView)
    |> render(:show, %{
      data: page.entries,
      paginate: %{
        page_number: page.page_number,
        page_size: page.page_size,
        total_pages: page.total_pages
      }
    })
  end

  def index(conn, params) do
    current_user = conn.assigns.current_user
    pagination_opts = get_pagination_opts(params)

    page =
      current_user.id
      |> Contacts.contacts_by_user_query()
      |> Contacts.preload_common_associations()
      |> Contacts.paginate(pagination_opts)

    conn
    |> put_view(WaltUiWeb.Api.ContactsView)
    |> render(:show, %{
      data: page.entries,
      paginate: %{
        page_number: page.page_number,
        page_size: page.page_size,
        total_pages: page.total_pages
      }
    })
  end

  def get_top_contacts(conn, _params) do
    current_user = conn.assigns.current_user

    top_contacts = Contacts.get_top_contacts(current_user.id)

    conn
    |> put_view(WaltUiWeb.Api.ContactsView)
    |> render(:show, %{data: top_contacts})
  end

  defparams :ptt_params do
    field :id, Ecto.UUID, required: true
  end

  def ptt(conn, params) do
    current_user = conn.assigns.current_user

    with {:ok, params} <- ptt_params(params),
         {:ok, contact} <- Contacts.fetch_contact(params.id),
         {:ok, :authorized} <- Authorization.authorize(current_user, :view, contact) do
      scores =
        contact.id
        |> Contacts.ptt_history()
        |> Enum.map(&Map.from_struct/1)
        |> Enum.map(&Map.take(&1, [:occurred_at, :score]))

      json(conn, %{data: scores})
    end
  end

  defparams :show_params do
    field :id, Ecto.UUID, required: true
  end

  def show(conn, params) do
    current_user = conn.assigns.current_user

    with {:ok, params} <- show_params(params),
         {:ok, contact} <- Contacts.fetch_contact(params.id),
         {:ok, :authorized} <- Authorization.authorize(current_user, :view, contact) do
      conn
      |> put_view(WaltUiWeb.Api.ContactsView)
      |> render(:show, %{data: contact})
    end
  end

  def create(conn, params) do
    current_user = conn.assigns.current_user

    contact_params =
      params
      |> Map.new(fn {k, v} -> {String.to_atom(k), v} end)
      |> Map.merge(%{user_id: current_user.id})

    with {:ok, contact} <- Contacts.create_contact(contact_params) do
      contact =
        contact
        |> Map.from_struct()
        |> Map.put(:unified_contact, nil)

      conn
      |> put_view(WaltUiWeb.Api.ContactsView)
      |> render(:show, %{data: contact})
    end
  end

  def bulk_create(conn, params) do
    %{"_json" => body} = params
    current_user = conn.assigns.current_user

    Logger.info("Received bulk contacts, count: #{Enum.count(body)}")

    Contacts.send_bulk_create_events(current_user, body)

    send_resp(conn, 202, "")
  end

  def bulk_upsert(conn, params) do
    %{"_json" => body} = params
    current_user = conn.assigns.current_user

    Logger.info("Received bulk contacts for upsert: #{Enum.count(body)}")
    Contacts.send_bulk_upsert_events(current_user, body)

    send_resp(conn, 202, "")
  end

  def update(conn, params) do
    {contact_id, contact_params} = Map.pop(params, "id")
    current_user = conn.assigns.current_user

    with {:ok, contact} <- Contacts.fetch_contact(contact_id),
         {:ok, :authorized} <- Authorization.authorize(current_user, :update, contact),
         {:ok, _aggregate_state} <- Contacts.update_contact(contact, contact_params) do
      updated_contact =
        contact
        |> Contact.changeset(contact_params)
        |> Ecto.Changeset.apply_changes()

      conn
      |> put_view(WaltUiWeb.Api.ContactsView)
      |> render(:show, %{data: updated_contact})
    end
  end

  def delete(conn, %{"id" => id}) do
    current_user = conn.assigns.current_user

    with {:ok, contact} <- Contacts.fetch_contact(id),
         {:ok, :authorized} <- Authorization.authorize(current_user, :view, contact),
         :ok <- Contacts.delete_contact(contact) do
      conn
      |> put_resp_content_type("application/json")
      |> send_resp(:no_content, "")
    end
  end

  defp get_pagination_opts(%{"page" => %{"number" => page_number, "size" => page_size}}) do
    %{page: page_number, page_size: page_size}
  end

  defp get_pagination_opts(%{"page" => %{"number" => page_number}}) do
    %{page: page_number}
  end

  defp get_pagination_opts(%{"page" => %{"size" => page_size}}) do
    %{page_size: page_size}
  end

  defp get_pagination_opts(_params) do
    %{}
  end
end
