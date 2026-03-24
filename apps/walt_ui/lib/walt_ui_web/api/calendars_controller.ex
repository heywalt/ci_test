defmodule WaltUiWeb.Api.CalendarsController do
  use WaltUiWeb, :controller

  import CozyParams

  require Logger

  alias WaltUi.Calendars
  alias WaltUi.ExternalAccounts

  action_fallback WaltUiWeb.FallbackController

  defparams :create_appointment_params do
    field :start_time, :string, required: true
    field :end_time, :string, required: true
    field :title, :string
    field :calendar_id, :string, required: true
    field :provider, :string, required: true
    field :description, :string
  end

  def create_appointment(conn, params) do
    current_user = conn.assigns.current_user

    with {:ok, params} <- create_appointment_params(params),
         {:ok, ea} <- ExternalAccounts.find_by_provider(current_user.external_accounts, :google),
         {:ok, calendar} <- Calendars.get(params.calendar_id),
         {:ok, _event} <- Calendars.create_appointment(ea, calendar, params) do
      conn
      |> put_status(:no_content)
      |> send_resp(:no_content, "")
    end
  end

  def todays_events(conn, params) do
    current_user = conn.assigns.current_user
    timezone = Map.get(params, "timezone", "UTC")

    with {:ok, ea} <- ExternalAccounts.find_by_provider(current_user.external_accounts, :google) do
      todays_events = Calendars.get_todays_events_with_contacts(current_user, ea, timezone)

      json(conn, todays_events)
    end
  end
end
