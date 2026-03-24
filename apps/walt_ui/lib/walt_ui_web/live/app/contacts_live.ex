defmodule WaltUiWeb.ContactsLive do
  @moduledoc false

  use WaltUiWeb, :live_view

  alias WaltUi.Account
  alias WaltUi.Contacts
  alias WaltUi.Search

  @per_page 30

  @impl true
  def mount(params, session, socket) do
    case Account.get_session(session["session_id"]) do
      {:ok, session} ->
        {:ok, current_user} = Account.get_user_with_subscription(session.user_id)

        if connected?(socket) do
          Phoenix.PubSub.subscribe(WaltUi.PubSub, "user:#{current_user.id}")
        end

        favorites = Contacts.list_favorites(current_user.id)

        # Initialize contacts and search state
        search_query = Map.get(params, "q", "")
        socket = apply_search_or_pagination(socket, search_query, current_user)

        {:ok,
         socket
         |> assign(
           page_title: "Contacts",
           meta_tags: %{
             title: "Contacts",
             description: "Manage your contacts"
           },
           og_tags: %{},
           current_user: current_user,
           favorites: favorites,
           loading: false
         )}

      {:error, _reason} ->
        {:ok,
         socket
         |> put_flash(:error, "Your session has expired. Please log in again.")
         |> redirect(to: ~p"/auth/auth0")}
    end
  end

  @impl true
  def handle_params(params, _url, socket) do
    search_query = Map.get(params, "q", "")

    # Only update if the search query has changed
    if search_query != socket.assigns.search_query do
      socket = apply_search_or_pagination(socket, search_query, socket.assigns.current_user)
      {:noreply, socket}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("restore-scroll", %{"position" => position, "page" => target_page}, socket) do
    current_page = socket.assigns.page

    # Load pages until we reach the target page
    if current_page < target_page do
      # Load all pages from current to target
      contacts_to_load =
        Enum.reduce((current_page + 1)..target_page, socket.assigns.contacts, fn page_num, acc ->
          page =
            Contacts.paginate_all_contacts(
              socket.assigns.current_user.id,
              %{page: page_num, page_size: @per_page}
            )

          acc ++ page.entries
        end)

      page =
        Contacts.paginate_all_contacts(
          socket.assigns.current_user.id,
          %{page: target_page, page_size: @per_page}
        )

      socket =
        assign(socket,
          contacts: contacts_to_load,
          page: target_page,
          has_more: target_page < page.total_pages,
          loading: false
        )

      # Send event back to JavaScript to restore scroll
      send(self(), {:scroll_restore, position})

      {:noreply, socket}
    else
      # Already at or past target page, just restore scroll
      send(self(), {:scroll_restore, position})
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("search", %{"query" => query}, socket) do
    query = String.trim(query)
    socket = apply_search_or_pagination(socket, query, socket.assigns.current_user)

    url = if query == "", do: ~p"/contacts", else: ~p"/contacts?q=#{query}"
    {:noreply, push_patch(socket, to: url)}
  end

  @impl true
  def handle_event("clear-search", _params, socket) do
    socket = apply_search_or_pagination(socket, "", socket.assigns.current_user)
    {:noreply, push_patch(socket, to: ~p"/contacts")}
  end

  @impl true
  def handle_event("load-more", _params, socket) do
    # Don't load more if in search mode
    if socket.assigns.search_mode do
      {:noreply, socket}
    else
      if socket.assigns.has_more && !socket.assigns.loading do
        socket = assign(socket, loading: true)
        next_page = socket.assigns.page + 1

        page =
          Contacts.paginate_all_contacts(
            socket.assigns.current_user.id,
            %{page: next_page, page_size: @per_page}
          )

        socket =
          assign(socket,
            contacts: socket.assigns.contacts ++ page.entries,
            page: next_page,
            has_more: next_page < page.total_pages,
            loading: false
          )

        # Send current page to JavaScript for better tracking
        socket = push_event(socket, "page-changed", %{page: next_page})

        {:noreply, socket}
      else
        {:noreply, socket}
      end
    end
  end

  @impl true
  def handle_info({:scroll_restore, position}, socket) do
    # Send JavaScript event to restore scroll position
    {:noreply, push_event(socket, "scroll-restored", %{position: position})}
  end

  @impl true
  def handle_info({_event, _data}, socket) do
    # Handle real-time updates from PubSub if needed
    {:noreply, socket}
  end

  # Helper functions for state management
  defp apply_search_or_pagination(socket, query, current_user) do
    if query != "" do
      perform_search(socket, query, current_user)
    else
      apply_normal_pagination(socket, current_user)
    end
  end

  defp perform_search(socket, query, current_user) do
    case Search.new_search_all_by_user(current_user.id, query) do
      search_results when is_map(search_results) ->
        contacts = Enum.map(search_results.hits, fn hit -> hit.document end)

        assign(socket,
          search_query: query,
          search_mode: true,
          search_results: contacts,
          contacts: contacts,
          has_more: false,
          page: 1,
          total_pages: 1
        )

      _ ->
        # Fall back to normal pagination if search fails
        socket
        |> apply_normal_pagination(current_user)
        |> put_flash(:error, "Search failed. Please try again.")
    end
  end

  defp apply_normal_pagination(socket, current_user) do
    favorites = Contacts.list_favorites(current_user.id)
    page = Contacts.paginate_all_contacts(current_user.id, %{page: 1, page_size: @per_page})

    assign(socket,
      search_query: "",
      search_mode: false,
      search_results: [],
      favorites: favorites,
      contacts: page.entries,
      page: page.page_number,
      total_pages: page.total_pages,
      has_more: page.page_number < page.total_pages
    )
  end

  # Helper functions for the template
  defp contact_name(contact) do
    name =
      [contact.first_name, contact.last_name]
      |> Enum.filter(& &1)
      |> Enum.join(" ")

    if name == "", do: "Unknown", else: name
  end

  defp contact_initials(contact) do
    first = if contact.first_name, do: String.first(contact.first_name), else: ""
    last = if contact.last_name, do: String.first(contact.last_name), else: ""
    initials = String.upcase(first <> last)

    if initials == "", do: "?", else: initials
  end

  defp ptt_circle(assigns) do
    ptt_score = assigns.ptt || 0
    display_score = ptt_score / 10

    # For stroke-dasharray: the circumference is approximately 100 units
    # We want the progress as a percentage of 10.0 max score
    circumference = 100
    progress_length = display_score / 10.0 * circumference
    gap_length = circumference - progress_length

    assigns =
      assigns
      |> Map.put(:ptt_score, ptt_score)
      |> Map.put(:progress_length, progress_length)
      |> Map.put(:gap_length, gap_length)
      |> Map.put(:display_score, display_score)

    ~H"""
    <div class="ptt-circle" data-ptt-score={@ptt_score}>
      <svg class="ptt-circle-svg" viewBox="0 0 36 36">
        <path
          class="ptt-circle-bg"
          d="M18 2.0845
            a 15.9155 15.9155 0 0 1 0 31.831
            a 15.9155 15.9155 0 0 1 0 -31.831"
        />
        <path
          class="ptt-circle-progress"
          d="M18 2.0845
            A 15.9155 15.9155 0 1 1 17.999 2.0845"
          stroke-dasharray="0 100"
          data-target-progress={"#{@progress_length} #{@gap_length}"}
        />
      </svg>
      <div class="ptt-circle-text" data-target-score={@display_score}>
        0.0
      </div>
    </div>
    """
  end
end
