defmodule WaltUiWeb.Admin.DashboardLive do
  @moduledoc false
  use WaltUiWeb, :live_view
  use Appsignal.Instrumentation.Decorators

  require Logger

  alias WaltUi.Account

  @page_size 50

  @impl true
  def mount(_params, session, socket) do
    current_user = session["current_user"]

    page = Account.list_users_with_contact_counts(page: 1, page_size: @page_size)

    {:ok,
     assign(socket,
       page_title: "Admin: Users",
       meta_tags: %{
         title: "Admin: Users",
         description: ""
       },
       og_tags: %{},
       current_user: current_user,
       users: page.entries,
       page: page.page_number,
       total_pages: page.total_pages,
       total_entries: page.total_entries,
       has_more: page.page_number < page.total_pages,
       sort_by: :inserted_at,
       sort_order: :desc,
       search_query: "",
       search_timer: nil,
       loading: false
     )}
  end

  @impl true
  def handle_event("show-flash", %{"type" => type, "message" => message}, socket) do
    flash_type =
      case type do
        "info" -> :info
        "error" -> :error
        _ -> :info
      end

    {:noreply, put_flash(socket, flash_type, message)}
  end

  def handle_event("sort", %{"by" => sort_by}, socket) do
    sort_by = String.to_existing_atom(sort_by)

    # Toggle sort order if clicking the same column
    sort_order =
      if socket.assigns.sort_by == sort_by do
        if socket.assigns.sort_order == :asc, do: :desc, else: :asc
      else
        # Default order for each column
        case sort_by do
          :name -> :asc
          :email -> :asc
          :contact_count -> :desc
          :inserted_at -> :desc
          _ -> :asc
        end
      end

    page =
      Account.list_users_with_contact_counts(
        order_by: sort_by,
        order: sort_order,
        search: socket.assigns.search_query,
        page: 1,
        page_size: @page_size
      )

    {:noreply,
     assign(socket,
       users: page.entries,
       page: page.page_number,
       total_pages: page.total_pages,
       total_entries: page.total_entries,
       has_more: page.page_number < page.total_pages,
       sort_by: sort_by,
       sort_order: sort_order
     )}
  end

  def handle_event("search", %{"query" => query}, socket) do
    # Cancel any existing timer
    if socket.assigns.search_timer do
      Process.cancel_timer(socket.assigns.search_timer)
    end

    # Set a new timer for debouncing (300ms delay)
    timer = Process.send_after(self(), {:perform_search, query}, 300)

    {:noreply, assign(socket, search_timer: timer, loading: true)}
  end

  def handle_event("search_submit", %{"query" => query}, socket) do
    # Immediate search on form submit (Enter key)
    # Cancel any pending timer
    if socket.assigns.search_timer do
      Process.cancel_timer(socket.assigns.search_timer)
    end

    page =
      Account.list_users_with_contact_counts(
        order_by: socket.assigns.sort_by,
        order: socket.assigns.sort_order,
        search: query,
        page: 1,
        page_size: @page_size
      )

    {:noreply,
     assign(socket,
       users: page.entries,
       page: page.page_number,
       total_pages: page.total_pages,
       total_entries: page.total_entries,
       has_more: page.page_number < page.total_pages,
       search_query: query,
       search_timer: nil,
       loading: false
     )}
  end

  def handle_event("clear_search", _params, socket) do
    # Cancel any pending timer
    if socket.assigns.search_timer do
      Process.cancel_timer(socket.assigns.search_timer)
    end

    page =
      Account.list_users_with_contact_counts(
        order_by: socket.assigns.sort_by,
        order: socket.assigns.sort_order,
        page: 1,
        page_size: @page_size
      )

    {:noreply,
     assign(socket,
       users: page.entries,
       page: page.page_number,
       total_pages: page.total_pages,
       total_entries: page.total_entries,
       has_more: page.page_number < page.total_pages,
       search_query: "",
       search_timer: nil,
       loading: false
     )}
  end

  def handle_event("load-more", _params, socket) do
    if socket.assigns.has_more && !socket.assigns.loading do
      next_page = socket.assigns.page + 1

      page =
        Account.list_users_with_contact_counts(
          order_by: socket.assigns.sort_by,
          order: socket.assigns.sort_order,
          search: socket.assigns.search_query,
          page: next_page,
          page_size: @page_size
        )

      {:noreply,
       assign(socket,
         users: socket.assigns.users ++ page.entries,
         page: page.page_number,
         has_more: page.page_number < page.total_pages,
         loading: false
       )}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_info({:perform_search, query}, socket) do
    page =
      Account.list_users_with_contact_counts(
        order_by: socket.assigns.sort_by,
        order: socket.assigns.sort_order,
        search: query,
        page: 1,
        page_size: @page_size
      )

    {:noreply,
     assign(socket,
       users: page.entries,
       page: page.page_number,
       total_pages: page.total_pages,
       total_entries: page.total_entries,
       has_more: page.page_number < page.total_pages,
       search_query: query,
       search_timer: nil,
       loading: false
     )}
  end

  # NOTE: Removing this function until we can implement proper RBAC to prevent unintended data loss.
  # @decorate channel_action()
  # def handle_event("purge_contacts", %{"id" => user_id}, socket) do
  #  admin = Map.get(socket.assigns, :current_user, %{})
  #  count = Contacts.delete_user_contacts(user_id)

  #  Logger.info("Deleted #{count} contacts",
  #    admin_id: Map.get(admin, :id),
  #    user_id: user_id
  #  )

  #  users = Account.list_users() |> Account.preload_contacts()

  #  {:noreply, assign(socket, users: users)}
  # end
end
