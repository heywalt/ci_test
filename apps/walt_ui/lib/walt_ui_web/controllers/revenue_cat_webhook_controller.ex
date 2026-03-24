defmodule WaltUiWeb.RevenueCatWebhookController do
  use WaltUiWeb, :controller

  require Logger

  # alias WaltUi.Account
  # alias WaltUi.RevenueCat.Client, as: RCClient
  alias WaltUi.Subscriptions

  plug WaltUi.RevenueCat.WebhookPlug when action in [:webhooks]

  def webhooks(%{body_params: %{"event" => event_body}} = conn, _params) do
    handle_webhook(event_body)
    handle_success(conn)
  end

  defp handle_webhook(%{"app_user_id" => user_id, "type" => type} = event)
       when type in ["INITIAL_PURCHASE", "RENEWAL"] do
    attrs = %{
      user_id: user_id,
      expires_on: get_expires_on(event),
      store: get_store(event),
      store_customer_id: user_id
    }

    # Q: do we need to be concerned with subscriptions from other stores....?
    # if a subscription for the given user exists, but from a different store, what should happen?
    Subscriptions.create_or_update(attrs)

    :ok
  end

  defp handle_webhook(%{"type" => unsupported_type} = event) do
    Logger.info("Unsupported RevenueCat Webhook event type: #{unsupported_type}",
      user_id: Map.get(event, "app_user_id")
    )

    :ok
  end

  defp handle_success(conn) do
    conn
    |> put_resp_content_type("text/plain")
    |> send_resp(200, "ok")
  end

  defp get_expires_on(%{"expiration_at_ms" => nil}), do: nil

  defp get_expires_on(%{"expiration_at_ms" => expires_date_ms}) do
    expires_date_ms
    |> DateTime.from_unix!(:millisecond)
    |> DateTime.to_naive()
  end

  defp get_store(%{"store" => "APP_STORE"}) do
    :apple
  end

  defp get_store(%{"store" => "PLAY_STORE"}) do
    :google
  end

  defp get_store(%{"store" => "STRIPE"}) do
    :stripe
  end

  defp get_store(%{"store" => unsupported_store} = event) do
    Logger.warning("Unsupported store: #{unsupported_store}",
      user_id: Map.get(event, "app_user_id")
    )
  end
end
