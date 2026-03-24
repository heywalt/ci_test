defmodule WaltUiWeb.Api.Contacts.NotesView do
  use JSONAPI.View, type: "notes"

  def fields do
    [:note, :contact_id, :inserted_at, :updated_at]
  end

  # def meta(data, _conn) do
  #   # this will add meta to each record
  #   # To add meta as a top level property, pass as argument to render function (shown below)
  #   %{meta_text: "meta_#{data[:text]}"}
  # end

  def inserted_at(%{inserted_at: inserted_at}, _conn) do
    DateTime.from_naive!(inserted_at, "Etc/UTC")
  end

  def updated_at(%{updated_at: updated_at}, _conn) do
    DateTime.from_naive!(updated_at, "Etc/UTC")
  end

  def relationships do
    # The post's author will be included by default
    [contacts: WaltUiWeb.Api.ContactsView]
  end
end
