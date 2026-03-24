defmodule WaltUi.Stripe do
  @moduledoc """
  The Stripe context.
  """

  require Logger

  alias Stripe.Checkout.Session

  @spec get_checkout_url(map(), String.t()) :: {:ok, String.t()} | {:error, atom()}
  def get_checkout_url(user, params) do
    promo_code = Map.get(params, :promo_code, nil)

    with {:ok, customer} <- find_or_create_customer(user),
         {:ok, price_id} <- get_default_price_id(params.product_id),
         {:ok, promo_id} <- translate_promo_code(promo_code),
         trial_period_days = get_trial_length(promo_code),
         {:ok, session} <-
           create_checkout_session(customer.id, price_id, promo_id, trial_period_days) do
      {:ok, session.url}
    else
      {:error, error} ->
        Logger.error("Error creating checkout session URL:", details: "#{inspect(error)}")

        {:error, error}
    end
  end

  @spec create_checkout_session(String.t(), String.t(), String.t() | nil, integer()) ::
          {:ok, map()} | {:error, atom()}
  def create_checkout_session(customer_id, price_id, promo_id, trial_period_days) do
    attrs = generate_checkout_session_attrs(customer_id, price_id, promo_id, trial_period_days)

    Session.create(attrs)
  end

  @spec find_or_create_customer(map()) :: {:ok, map()} | {:error, Stripe.Error.t()}
  def find_or_create_customer(user) do
    case find_stripe_customer_by_email(user.email) do
      {:ok, customer} -> {:ok, customer}
      {:error, :not_found} -> create_customer(user)
      {:error, error} -> {:error, error}
    end
  end

  @spec create_customer(map()) :: {:ok, map()} | {:error, Stripe.Error.t()}
  def create_customer(user) do
    name = "#{user.first_name} #{user.last_name}" |> String.trim()
    params = %{email: user.email, name: name, phone: user.phone}

    Stripe.Customer.create(params)
  end

  @spec find_stripe_customer_by_email(String.t()) :: {:ok, map()} | {:error, atom()}
  def find_stripe_customer_by_email(email) do
    params = %{
      query: "email:'#{email}'"
    }

    case Stripe.Customer.search(params) do
      {:ok, %{data: [customer | _]}} -> {:ok, customer}
      {:ok, %{data: []}} -> {:error, :not_found}
      {:error, error} -> {:error, error}
    end
  end

  @spec get_default_price_id(String.t()) :: {:ok, String.t()} | {:error, atom()}
  def get_default_price_id(product_id) do
    case Stripe.Price.list(%{product: product_id, active: true}) do
      {:ok, %Stripe.List{data: prices}} when prices != [] ->
        # Get the first price (or you could implement logic to find a specific one)
        price = List.first(prices)
        {:ok, price.id}

      {:ok, %Stripe.List{data: []}} ->
        {:error, :no_prices_found}

      {:error, error} ->
        {:error, error}
    end
  end

  @spec translate_promo_code(String.t() | nil) :: {:ok, map()} | {:ok, nil}
  def translate_promo_code(nil), do: {:ok, nil}

  def translate_promo_code(promo_code) do
    case Stripe.PromotionCode.list(%{code: promo_code}) do
      {:ok, %Stripe.List{data: [promo_code | _]}} ->
        {:ok, promo_code.id}

      {:ok, %Stripe.List{data: []}} ->
        {:error, :not_found}

      {:error, error} ->
        Logger.error("Error translating promo code:", details: "#{inspect(error)}")

        {:error, error}
    end
  end

  defp generate_checkout_session_attrs(customer_id, price_id, nil, trial_period_days) do
    %{
      customer: customer_id,
      line_items: [%{price: price_id, quantity: 1}],
      mode: :subscription,
      allow_promotion_codes: true,
      success_url: config()[:success_url],
      cancel_url: config()[:cancel_url],
      subscription_data: %{
        trial_period_days: trial_period_days
      }
    }
  end

  defp generate_checkout_session_attrs(customer_id, price_id, promo_id, 0) do
    %{
      customer: customer_id,
      line_items: [%{price: price_id, quantity: 1}],
      mode: :subscription,
      discounts: [%{promotion_code: promo_id}],
      success_url: config()[:success_url],
      cancel_url: config()[:cancel_url]
    }
  end

  defp generate_checkout_session_attrs(customer_id, price_id, promo_id, trial_period_days) do
    %{
      customer: customer_id,
      line_items: [%{price: price_id, quantity: 1}],
      mode: :subscription,
      discounts: [%{promotion_code: promo_id}],
      success_url: config()[:success_url],
      cancel_url: config()[:cancel_url],
      subscription_data: %{
        trial_period_days: trial_period_days
      }
    }
  end

  defp get_trial_length(code) do
    case code do
      code when code in ~w(C212025 EASYSTREET2025 HOMIE REALTYONE RL2025 VISTASOTHEBYS) -> 90
      code when code in ~w(AWM2025 CBCARLSBAD2025 NAHREP2025 VIRTUE2025) -> 60
      code when code in ~w(MIKEP2025) -> 0
      _ -> 30
    end
  end

  defp config do
    Application.get_env(:walt_ui, :stripe)
  end
end
