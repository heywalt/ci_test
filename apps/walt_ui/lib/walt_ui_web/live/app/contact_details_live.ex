defmodule WaltUiWeb.ContactDetailsLive do
  @moduledoc false

  use WaltUiWeb, :live_view

  alias WaltUi.Account
  alias WaltUi.Contacts

  @impl true
  def mount(%{"id" => contact_id}, session, socket) do
    with {:ok, session} <- Account.get_session(session["session_id"]),
         {:ok, current_user} <- Account.get_user_with_subscription(session.user_id),
         {:ok, contact} <- Contacts.fetch_contact(contact_id) do
      {:ok,
       assign(socket,
         page_title: contact_name(contact),
         meta_tags: %{
           title: "Contact Details - #{contact_name(contact)}",
           description: "View contact information for #{contact_name(contact)}"
         },
         og_tags: %{},
         current_user: current_user,
         contact: contact
       )}
    else
      {:error, :contact_not_found} ->
        {:ok,
         socket
         |> put_flash(:error, "Contact not found")
         |> redirect(to: ~p"/contacts")}

      {:error, _reason} ->
        {:ok,
         socket
         |> put_flash(:error, "Your session has expired. Please log in again.")
         |> redirect(to: ~p"/auth/auth0")}
    end
  end

  @impl true
  def handle_event("toggle_favorite", _params, socket) do
    contact = socket.assigns.contact
    new_favorite_status = !contact.is_favorite

    case Contacts.update_contact(contact, %{is_favorite: new_favorite_status}) do
      {:ok, _} ->
        updated_contact = %{contact | is_favorite: new_favorite_status}
        message = if new_favorite_status, do: "Added to favorites", else: "Removed from favorites"

        {:noreply,
         socket
         |> assign(contact: updated_contact)
         |> put_flash(:info, message)}

      {:error, _reason} ->
        {:noreply, put_flash(socket, :error, "Failed to update favorite status")}
    end
  end

  @impl true
  def handle_info({_event, _data}, socket) do
    {:noreply, socket}
  end

  # Helper functions
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

  defp format_address(contact) do
    address_parts =
      [
        contact.street_1,
        contact.street_2,
        contact.city,
        [contact.state, contact.zip] |> Enum.filter(& &1) |> Enum.join(" ")
      ]
      |> Enum.filter(&(&1 && &1 != ""))

    if address_parts == [], do: nil, else: Enum.join(address_parts, ", ")
  end

  defp format_phone_numbers(contact) do
    if contact.phone_numbers && contact.phone_numbers != [] do
      contact.phone_numbers
    else
      if contact.phone, do: [contact.phone], else: []
    end
  end

  defp format_emails(contact) do
    if contact.emails && contact.emails != [] do
      contact.emails
    else
      if contact.email, do: [contact.email], else: []
    end
  end

  defp format_date(nil), do: nil

  defp format_date(%NaiveDateTime{} = date) do
    Calendar.strftime(date, "%B %d, %Y")
  end

  defp format_date(%DateTime{} = date) do
    Calendar.strftime(date, "%B %d, %Y")
  end

  defp format_date(%Date{} = date) do
    Calendar.strftime(date, "%B %d, %Y")
  end

  defp format_date(date) when is_binary(date) do
    case Date.from_iso8601(date) do
      {:ok, parsed_date} -> format_date(parsed_date)
      _ -> date
    end
  end

  defp format_currency(nil), do: nil

  defp format_currency(amount) when is_number(amount) do
    formatted_amount = :erlang.float_to_binary(amount / 1.0, decimals: 0)
    "$#{formatted_amount}"
  end

  defp format_currency(amount), do: amount

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
