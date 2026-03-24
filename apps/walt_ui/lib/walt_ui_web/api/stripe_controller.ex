defmodule WaltUiWeb.Api.StripeController do
  use WaltUiWeb, :controller

  import CozyParams

  alias WaltUi.Stripe

  action_fallback WaltUiWeb.FallbackController

  defparams :create_checkout_session_params do
    field :product_id, :string, required: true
    field :promo_code, :string, required: false
  end

  def create_checkout_session(conn, params) do
    current_user = conn.assigns.current_user

    with {:ok, params} <- create_checkout_session_params(params),
         {:ok, checkout_session_url} <- Stripe.get_checkout_url(current_user, params) do
      conn
      |> put_status(:created)
      |> json(%{data: checkout_session_url})
    end
  end
end
