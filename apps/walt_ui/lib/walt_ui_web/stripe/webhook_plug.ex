defmodule WaltUi.Stripe.WebhookPlug do
  @moduledoc false

  @behaviour Plug

  use Appsignal.Instrumentation.Decorators

  import Plug.Conn

  require Logger

  @impl true
  def init(config), do: config

  @decorate transaction()
  @impl true
  def call(%{request_path: "/webhooks/stripe"} = conn, _) do
    Logger.info("Stripe Webhook Plug: Stripe webhook received", details: conn.request_path)

    signing_secret = Application.get_env(:stripity_stripe, :signing_secret)
    [stripe_signature] = Plug.Conn.get_req_header(conn, "stripe-signature")

    with {:ok, body, _} <- Plug.Conn.read_body(conn),
         {:ok, stripe_event} <-
           Stripe.Webhook.construct_event(body, stripe_signature, signing_secret) do
      conn = Plug.Conn.assign(conn, :stripe_event, stripe_event)

      Logger.info("Stripe Webhook Plug processed:", details: inspect(conn.assigns.stripe_event))

      conn
    else
      {:error, error} ->
        Logger.warning("Failed to verify Stripe webhook: #{inspect(error)}")

        conn
        |> send_resp(:bad_request, error)
        |> halt()
    end
  end

  def call(conn, _), do: conn
end
