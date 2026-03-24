defmodule WaltUiWeb.StripeHandlerTest do
  use Repo.DataCase

  import WaltUi.AccountFixtures

  alias WaltUi.Subscriptions
  alias WaltUiWeb.StripeHandler

  setup do
    user = user_fixture()
    date = Date.add(Date.utc_today(), 30)

    {:ok, %{date: date, user: user}}
  end

  describe "handle_event/1 customer.subscription.updated" do
    test "updates expires_on when subscription is found", %{user: user, date: date} do
      {:ok, _sub} =
        Subscriptions.create(%{
          user_id: user.id,
          store: :stripe,
          store_customer_id: "cus_12345",
          expires_on: date
        })

      cancel_at = DateTime.to_unix(~U[2027-06-15 00:00:00Z])

      event = %Stripe.Event{
        id: "evt_test_123",
        type: "customer.subscription.updated",
        data: %{object: %{cancel_at: cancel_at, customer: "cus_12345"}}
      }

      assert :ok = StripeHandler.handle_event(event)

      {:ok, updated} = Subscriptions.get_subscription_by_store_customer_id("cus_12345")
      assert updated.expires_on == ~D[2027-06-15]
    end

    test "returns :ok when cancel_at is nil" do
      event = %Stripe.Event{
        id: "evt_test_456",
        type: "customer.subscription.updated",
        data: %{object: %{cancel_at: nil, customer: "cus_99999"}}
      }

      assert :ok = StripeHandler.handle_event(event)
    end

    test "returns :ok when subscription is not found" do
      cancel_at = DateTime.to_unix(~U[2027-06-15 00:00:00Z])

      event = %Stripe.Event{
        id: "evt_test_789",
        type: "customer.subscription.updated",
        data: %{object: %{cancel_at: cancel_at, customer: "cus_nonexistent"}}
      }

      assert :ok = StripeHandler.handle_event(event)
    end
  end
end
