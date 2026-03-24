defmodule WaltUiWeb.Api.ContactInteractionsController do
  use WaltUiWeb, :controller

  import CozyParams

  require Logger

  alias WaltUi.ContactInteractions
  alias WaltUi.Contacts
  alias WaltUiWeb.Authorization

  action_fallback WaltUiWeb.FallbackController

  defparams :contact_interaction_params do
    field :contact_id, Ecto.UUID, required: true
  end

  def index(conn, params) do
    current_user = conn.assigns.current_user

    with {:ok, params} <- contact_interaction_params(params),
         {:ok, contact} <- Contacts.fetch_contact(params.contact_id),
         {:ok, :authorized} <-
           Authorization.authorize(current_user, :view, contact) do
      params.contact_id
      |> ContactInteractions.for_contact()
      |> then(&json(conn, %{data: &1}))
    end
  end
end
