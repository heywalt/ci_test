defmodule WaltUiWeb.StripeHandler do
  @moduledoc false

  use Appsignal.Instrumentation.Decorators

  require Logger

  alias WaltUi.Account
  alias WaltUi.RevenueCat.Client, as: RCClient
  alias WaltUi.Subscriptions

  def handle_event(%Stripe.Event{type: "customer.created"} = stripe_event) do
    Logger.info(
      "Stripe customer.created event received",
      details: stripe_event.data.object.email,
      stripe_event_id: stripe_event.id
    )

    with {:ok, email} <- get_email_from_stripe_event(stripe_event),
         {:ok, user} <- Account.get_user_by_email(email) do
      Subscriptions.create_or_update(%{
        store: :stripe,
        store_customer_id: stripe_event.data.object.id,
        user_id: user.id
      })

      :ok
    else
      {:error, :no_email} ->
        Logger.error(
          "Failed to find email in Stripe customer.created event",
          stripe_event_id: stripe_event.id
        )

        {:error, "Failed to find email in Stripe customer.created event"}

      {:error, :not_found} ->
        Logger.error(
          "Failed to find user for Stripe customer.created event via email",
          stripe_event_id: stripe_event.id
        )

        {:error, "Failed to find user for Stripe customer.created event"}
    end
  end

  @decorate transaction_event()
  def handle_event(%Stripe.Event{type: "customer.subscription.created"} = stripe_event) do
    Logger.info(
      "Stripe customer.subscription.created event received",
      stripe_event_id: stripe_event.id
    )

    with {:ok, sub_id} <- get_stripe_subscription_id(stripe_event),
         {:ok, expires_on_ms} <- get_expires_on_ms(stripe_event),
         {:ok, customer_id} <- get_customer_id(stripe_event),
         {:ok, sub} <- Subscriptions.get_subscription_by_store_customer_id(customer_id) do
      {:ok, dt} = DateTime.from_unix(expires_on_ms)
      date = DateTime.to_naive(dt)

      {:ok, sub} = Subscriptions.update(sub, %{expires_on: date, store_subscription_id: sub_id})

      Task.Supervisor.async_nolink(WaltUi.TaskSupervisor, fn ->
        Logger.info("Sending Stripe subscription to RevenueCat",
          details: sub_id,
          user_id: sub.user_id
        )

        RCClient.send_stripe_subscription(sub.user_id, sub_id)
      end)

      Phoenix.PubSub.broadcast(WaltUi.PubSub, "user:#{sub.user_id}", {
        "subscription:created",
        sub
      })

      :ok
    else
      {:error, error} ->
        Logger.warning("Failed to handle Stripe customer.subscription.created event",
          error: error,
          stripe_event_id: stripe_event.id
        )
    end
  end

  def handle_event(%Stripe.Event{type: "customer.subscription.updated"} = stripe_event) do
    Logger.info(
      "Stripe customer.subscription.updated event received",
      stripe_event_id: stripe_event.id
    )

    with {:ok, cancel_at} <- get_cancel_at(stripe_event),
         {:ok, customer_id} <- get_customer_id(stripe_event),
         {:ok, sub} <- Subscriptions.get_subscription_by_store_customer_id(customer_id) do
      date =
        cancel_at
        |> DateTime.from_unix()
        |> then(fn {:ok, dt} -> dt end)
        |> DateTime.to_naive()

      {:ok, sub} = Subscriptions.update(sub, %{expires_on: date})

      Phoenix.PubSub.broadcast(WaltUi.PubSub, "user:#{sub.user_id}", {
        "subscription:updated",
        sub
      })

      :ok
    else
      {:error, :no_cancel_at} ->
        :ok

      {:error, error} ->
        Logger.warning("Failed to handle Stripe customer.subscription.updated event",
          error: error,
          stripe_event_id: stripe_event.id
        )

        :ok
    end
  end

  def handle_event(%Stripe.Event{type: "checkout.session.completed"} = stripe_event) do
    Logger.info(
      "Stripe checkout.session.completed event received",
      details: stripe_event.data.object.customer_email,
      stripe_event_id: stripe_event.id
    )

    :ok
  end

  # Placehodler for unhandled events
  def handle_event(%Stripe.Event{} = stripe_event) do
    Logger.info(
      "Unhandled Stripe #{inspect(stripe_event.type)} event received",
      stripe_event_id: stripe_event.id
    )

    :ok
  end

  @decorate transaction_event()
  defp get_stripe_subscription_id(data)

  defp get_stripe_subscription_id(%{data: %{object: %{id: nil}}}) do
    {:error, :no_subscription_id}
  end

  defp get_stripe_subscription_id(%{data: %{object: %{id: id}}}) do
    {:ok, id}
  end

  @decorate transaction_event()
  defp get_email_from_stripe_event(data)

  defp get_email_from_stripe_event(%{data: %{object: %{email: nil}}}) do
    {:error, :no_email}
  end

  defp get_email_from_stripe_event(%{data: %{object: %{email: email}}}) do
    {:ok, email}
  end

  @decorate transaction_event()
  defp get_expires_on_ms(data)

  defp get_expires_on_ms(%{data: %{object: %{current_period_end: nil}}}) do
    {:error, :no_expires_on}
  end

  defp get_expires_on_ms(%{data: %{object: %{current_period_end: expires_on_ms}}}) do
    {:ok, expires_on_ms}
  end

  @decorate transaction_event()
  defp get_customer_id(data)

  defp get_customer_id(%{data: %{object: %{customer: nil}}}) do
    {:error, :no_customer_id}
  end

  defp get_customer_id(%{data: %{object: %{customer: customer_id}}}) do
    {:ok, customer_id}
  end

  defp get_cancel_at(%{data: %{object: %{cancel_at: nil}}}), do: {:error, :no_cancel_at}
  defp get_cancel_at(%{data: %{object: %{cancel_at: cancel_at}}}), do: {:ok, cancel_at}
end
