defmodule WaltUi.RevenueCat.Client do
  @moduledoc """
  Context for interacting with RevenueCat.

  Currently just used to send Stripe subscription receipts to RevenueCat.
  """

  use Appsignal.Instrumentation.Decorators

  require Logger

  @decorate transaction_event()
  @spec send_stripe_subscription(String.t(), String.t()) :: {:ok, any} | {:error, any()}
  def send_stripe_subscription(user_id, subscription_id) do
    client()
    |> Tesla.post("v1/receipts", %{app_user_id: user_id, fetch_token: subscription_id})
    |> handle_response()
  end

  defp config do
    Application.get_env(:walt_ui, :revenue_cat)
  end

  defp client do
    Tesla.client(
      [
        {Tesla.Middleware.BaseUrl, config()[:base_url]},
        Tesla.Middleware.JSON,
        {Tesla.Middleware.BearerAuth, token: config()[:public_api_key]},
        {Tesla.Middleware.Headers, [{"X-Platform", "stripe"}]},
        {Tesla.Middleware.Retry,
         delay: 500,
         max_delay: 1_000,
         max_retries: 10,
         should_retry: fn
           {:error, :timeout} -> true
           {:error, :checkout_timeout} -> true
           _else -> false
         end}
      ],
      Tesla.Adapter.Hackney
    )
  end

  defp handle_response({:ok, %{status: 200, body: body}}) do
    {:ok, body}
  end

  defp handle_response({:ok, %{status: code, body: error_body}}) do
    Logger.warning("Error sending event to RevenueCat",
      error_code: code,
      details: inspect(error_body)
    )

    {:error, error_body}
  end
end
