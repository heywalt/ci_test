defmodule WaltUi.Subscriptions do
  @moduledoc """
  Context module for interfacing with Stripe Subscriptions.
  """

  use Appsignal.Instrumentation.Decorators

  require Logger

  alias WaltUi.Account.User
  alias WaltUi.Geocoding.GeocodeUserContactsJob
  alias WaltUi.Subscriptions.Subscription

  @spec create(map()) :: {:ok, Subscription.t()} | {:error, Ecto.Changeset.t()}
  def create(attrs) do
    %Subscription{}
    |> Subscription.changeset(attrs)
    |> Repo.insert()
    |> tap(&update_user_tier/1)
  end

  @decorate transaction_event()
  @spec update(Subscription.t(), map()) :: {:ok, Subscription.t()} | {:error, Ecto.Changeset.t()}
  def update(subscription, attrs) do
    subscription
    |> Subscription.changeset(attrs)
    |> Repo.update()
    |> tap(&update_user_tier/1)
  end

  @spec get(String.t()) :: Subscription.t() | nil
  def get(id) do
    Repo.get(Subscription, id)
  end

  @spec create_or_update(map()) :: {:ok, Subscription.t()}
  def create_or_update(attrs) do
    case get_subscription_by_user_id(attrs.user_id) do
      nil ->
        create(attrs)

      sub ->
        attrs = maybe_preserve_store_customer_id(sub, attrs)
        update(sub, attrs)
    end
  end

  # When a subscription exists, and already has an ID, it is likely because it is a Stripe subscription.
  # Just to be on the safe side, we default to leaving the customer_store_id alone if it exists, regardless
  # of store.
  defp maybe_preserve_store_customer_id(
         %Subscription{store_customer_id: scid},
         attrs
       )
       when is_binary(scid) and scid != "" do
    Map.delete(attrs, :store_customer_id)
  end

  defp maybe_preserve_store_customer_id(_sub, attrs), do: attrs

  @spec get_subscription_by_user_id(String.t()) :: Subscription.t() | nil
  def get_subscription_by_user_id(user_id) do
    Repo.get_by(Subscription, user_id: user_id)
  end

  @decorate transaction_event()
  @spec get_subscription_by_store_customer_id(String.t()) ::
          {:ok, Subscription.t()} | {:error, atom()}
  def get_subscription_by_store_customer_id(store_customer_id) do
    case Repo.get_by(Subscription, store_customer_id: store_customer_id) do
      nil -> {:error, :not_found}
      sub -> {:ok, sub}
    end
  end

  @spec get_stripe_customer_id(User.t()) :: {:ok, String.t()} | {:error, atom()}
  def get_stripe_customer_id(user) do
    user = Repo.preload(user, :subscription)

    case user.subscription do
      nil -> find_or_create_stripe_customer(user)
      sub -> determine_store_customer_id(sub)
    end
  end

  defp find_or_create_stripe_customer(user) do
    with {:ok, resp} <- Stripe.Customer.search(%{query: "email:'#{user.email}'"}),
         {:search, []} <- {:search, resp.data},
         {:ok, stripe_customer} <- create_stripe_customer(user),
         {:ok, sub} <- create_subscription(stripe_customer, user) do
      {:ok, sub.store_customer_id}
    else
      {:search, [customer | _]} ->
        {:ok, customer.id}

      {:error, error} ->
        Logger.warning("Error searching for Stripe customer: #{inspect(error)}", user_id: user.id)
        {:error, :not_found}
    end
  end

  defp create_stripe_customer(user) do
    case Stripe.Customer.create(%{
           email: user.email,
           name: "#{user.first_name} #{user.last_name}"
         }) do
      {:ok, stripe_customer} -> {:ok, stripe_customer}
      {:error, _} -> {:error, :could_not_create_stripe_customer}
    end
  end

  defp create_subscription(stripe_customer, user) do
    create(%{
      user_id: user.id,
      store: :stripe,
      store_customer_id: stripe_customer.id
    })
  end

  defp determine_store_customer_id(sub) do
    case sub.store do
      :stripe -> {:ok, sub.store_customer_id}
      _ -> {:error, :not_found}
    end
  end

  defp update_user_tier({:ok, %{expires_on: nil}}) do
    :ok
  end

  defp update_user_tier({:ok, sub}) do
    yesterday = Date.add(Date.utc_today(), -1)

    with true <- Date.after?(sub.expires_on, yesterday),
         user when not is_nil(user) <- WaltUi.Account.get_user(sub.user_id) do
      old_tier = user.tier
      {:ok, updated_user} = WaltUi.Account.update_user(user, %{tier: :premium})

      # Trigger geocoding if user upgraded from freemium to premium
      if old_tier == :freemium and updated_user.tier == :premium do
        schedule_premium_upgrade_geocoding(updated_user.id)
      end

      {:ok, updated_user}
    end
  end

  defp update_user_tier(_error), do: :ok

  defp schedule_premium_upgrade_geocoding(user_id) do
    Logger.info("User upgraded to premium, scheduling geocoding jobs", user_id: user_id)

    # Phase 1: Immediate geocoding of existing addressable contacts
    %{user_id: user_id, phase: "immediate"}
    |> GeocodeUserContactsJob.new()
    |> Oban.insert()

    # Phase 2: Delayed geocoding to catch in-flight enrichments (10 minutes delay)
    %{user_id: user_id, phase: "delayed"}
    |> GeocodeUserContactsJob.new(schedule_in: 600)
    |> Oban.insert()

    :ok
  end
end
