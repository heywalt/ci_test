defmodule WaltUiWeb.Api.Contacts.EventsView do
  use JSONAPI.View, type: "contact_events"

  def fields do
    [:event, :note_id, :type, :inserted_at, :updated_at]
  end

  def inserted_at(%{inserted_at: inserted_at}, _conn) do
    DateTime.from_naive!(inserted_at, "Etc/UTC")
  end

  def updated_at(%{updated_at: updated_at}, _conn) do
    DateTime.from_naive!(updated_at, "Etc/UTC")
  end

  def relationships do
    [
      contact: {:contact, WaltUiWeb.Api.Contacts.ContactsView},
      note: {:note, WaltUiWeb.Api.Contacts.NotesView}
    ]
  end
end
