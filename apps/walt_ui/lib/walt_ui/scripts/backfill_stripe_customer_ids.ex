defmodule WaltUi.Scripts.BackfillStripeCustomerIds do
  @moduledoc """
  Script to repair subscriptions where `store_customer_id` was overwritten
  by RevenueCat with the RC user ID instead of the real Stripe customer ID.

  Looks up the correct Stripe customer ID via the user's email and updates
  the subscription if it differs.

  Run via: WaltUi.Scripts.BackfillStripeCustomerIds.run()
  """

  import Ecto.Query

  require Logger

  alias WaltUi.Account.User
  alias WaltUi.Stripe
  alias WaltUi.Subscriptions
  alias WaltUi.Subscriptions.Subscription

  def run do
    subscriptions_query()
    |> Repo.all()
    |> Enum.reduce(%{updated: 0, skipped: 0, not_found: 0, errors: 0}, fn sub, acc ->
      case repair_subscription(sub) do
        :updated -> %{acc | updated: acc.updated + 1}
        :skipped -> %{acc | skipped: acc.skipped + 1}
        :not_found -> %{acc | not_found: acc.not_found + 1}
        :error -> %{acc | errors: acc.errors + 1}
      end
    end)
  end

  def subscriptions_query do
    from s in Subscription,
      join: u in User,
      on: s.user_id == u.id,
      where: not is_nil(u.email) and s.store == :stripe,
      preload: [user: u]
  end

  def repair_subscription(sub) do
    case Stripe.find_stripe_customer_by_email(sub.user.email) do
      {:ok, customer} ->
        if customer.id != sub.store_customer_id do
          Logger.info("Updating store_customer_id for user #{sub.user_id}",
            old: sub.store_customer_id,
            new: customer.id
          )

          {:ok, _} = Subscriptions.update(sub, %{store_customer_id: customer.id})
          :updated
        else
          :skipped
        end

      {:error, :not_found} ->
        Logger.info("No Stripe customer found for user #{sub.user_id}",
          email: sub.user.email
        )

        :not_found

      {:error, error} ->
        Logger.warning("Error looking up Stripe customer for user #{sub.user_id}",
          error: inspect(error)
        )

        :error
    end
  end
end
