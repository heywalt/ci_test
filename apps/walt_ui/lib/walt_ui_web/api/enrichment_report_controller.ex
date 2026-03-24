defmodule WaltUiWeb.Api.EnrichmentReportController do
  use WaltUiWeb, :controller

  require Logger

  alias WaltUi.Contacts

  action_fallback WaltUiWeb.FallbackController

  def index(conn, _params) do
    conn.assigns.current_user.id
    |> Contacts.get_enrichment_report()
    |> Map.put(:new_enrichments, [])
    |> then(&json(conn, %{data: &1}))
  end
end
