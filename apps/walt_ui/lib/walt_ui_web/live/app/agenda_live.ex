defmodule WaltUiWeb.AgendaLive do
  @moduledoc false

  use WaltUiWeb, :live_view

  alias WaltUi.Account

  @impl true
  def mount(_params, session, socket) do
    case Account.get_session(session["session_id"]) do
      {:ok, session} ->
        {:ok, current_user} = Account.get_user_with_subscription(session.user_id)

        if connected?(socket) do
          Phoenix.PubSub.subscribe(WaltUi.PubSub, "user:#{current_user.id}")
        end

        {:ok,
         assign(socket,
           page_title: "Agenda",
           meta_tags: %{
             title: "Agenda",
             description: "View your upcoming events and tasks"
           },
           og_tags: %{},
           current_user: current_user
         )}

      {:error, _reason} ->
        {:ok,
         socket
         |> put_flash(:error, "Your session has expired. Please log in again.")
         |> redirect(to: ~p"/auth/auth0")}
    end
  end

  @impl true
  def handle_info({_event, _data}, socket) do
    # Handle real-time updates from PubSub if needed
    {:noreply, socket}
  end
end
