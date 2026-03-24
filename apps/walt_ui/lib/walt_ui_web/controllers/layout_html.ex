defmodule WaltUiWeb.LayoutHTML do
  use WaltUiWeb, :html

  embed_templates "layout_html/*"

  def show_tab_navigation?(socket) do
    socket.view in [WaltUiWeb.ContactsLive, WaltUiWeb.AgendaLive]
  end
end
