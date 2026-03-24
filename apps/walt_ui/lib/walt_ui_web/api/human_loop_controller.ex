defmodule WaltUiWeb.Api.HumanLoopController do
  use WaltUiWeb, :controller

  import CozyParams

  require Logger

  alias WaltUi.Contacts
  alias WaltUi.HumanLoop

  action_fallback WaltUiWeb.FallbackController

  @get_text_prompt_id "pr_4fUr1MC1pgi36HrVpgunq"

  defparams :get_text_params do
    field :contact_id, :string, required: true
  end

  def get_text_message(conn, params) do
    current_user = conn.assigns.current_user

    with {:ok, params} <- get_text_params(params),
         {:ok, contact} <- Contacts.fetch_contact(params.contact_id),
         {:ok, message} <- HumanLoop.call_prompt(@get_text_prompt_id, contact, current_user) do
      conn
      |> put_status(:ok)
      |> json(%{data: message})
    end
  end
end
