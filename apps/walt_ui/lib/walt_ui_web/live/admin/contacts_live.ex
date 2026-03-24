defmodule WaltUiWeb.Admin.ContactsLive do
  @moduledoc false

  use WaltUiWeb, :live_view
  import WaltUiWeb.AdminComponents

  alias WaltUi.Admin.ContactMetadata
  alias WaltUi.Contacts
  alias WaltUi.Enrichment.Endato
  alias WaltUi.Enrichment.Faraday

  @impl true
  def mount(%{"id" => id}, session, socket) do
    current_user = session["current_user"]

    {:ok, contact} = Contacts.fetch_contact(id)

    # Transform enrichment data into structured metadata
    {metadata, metadata_json} = ContactMetadata.build_unified_metadata(contact)

    # Fetch individual provider data for admin debugging
    provider_data = ContactMetadata.fetch_provider_data(contact)

    {:ok,
     assign(socket,
       page_title: "Admin: Contact",
       meta_tags: %{
         title: "Contact Details",
         description: "Contact: #{contact.first_name} #{contact.last_name}"
       },
       og_tags: %{},
       current_user: current_user,
       contact: contact,
       contact_metadata: metadata,
       contact_meta: metadata_json,
       provider_data: provider_data,
       endato_output: nil,
       faraday_output: nil
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

  def handle_event("call_endato", _, socket) do
    contact = socket.assigns.contact

    {status, results} = Endato.fetch_contact(contact)
    results = Jason.encode!(results, %{escape: :html_safe, pretty: true})

    {:noreply, assign(socket, endato_status: status, endato_output: results)}
  end

  def handle_event("call_faraday", _, socket) do
    contact = socket.assigns.contact

    {status, results} = Faraday.fetch_contact(contact)
    results = Jason.encode!(results, %{escape: :html_safe, pretty: true})

    {:noreply, assign(socket, faraday_status: status, faraday_output: results)}
  end

  # Helper function for displaying values with "Not available" fallback
  def display_value(value) do
    if value do
      Phoenix.HTML.raw("{#{value}}")
    else
      Phoenix.HTML.raw(~s(<span style="color: #9ca3af; font-style: italic;">Not available</span>))
    end
  end
end
