defmodule WaltUi.SubscriptionsTest do
  use Repo.DataCase
  use Mimic

  import WaltUi.AccountFixtures

  alias WaltUi.Subscriptions

  setup :verify_on_exit!

  setup do
    user = user_fixture()
    date = Date.add(Date.utc_today(), 30)

    {:ok, %{date: date, user: user}}
  end

  describe "create/1" do
    test "creates a valid subscription with valid attributes", %{user: user, date: date} do
      attrs = %{user_id: user.id, store: :stripe, expires_on: date}

      assert {:ok, _subscription} = Subscriptions.create(attrs)
      assert %{tier: :premium} = Repo.reload(user)
    end

    test "returns an error changeset with missing required attrs", %{user: user, date: date} do
      attrs = %{user_id: user.id, expires_on: date}

      assert {:error, %{errors: [store: {"can't be blank", [validation: :required]}]}} =
               Subscriptions.create(attrs)

      assert %{tier: :freemium} = Repo.reload(user)
    end
  end

  describe "update/2" do
    test "updates a subscription with valid attributes", %{user: user, date: date} do
      attrs = %{user_id: user.id, store: :stripe, expires_on: date}

      assert {:ok, sub} = Subscriptions.create(attrs)

      new_expiration_date = ~N[2026-11-25 11:17:46]

      assert {:ok, subscription} =
               Subscriptions.update(sub, %{expires_on: new_expiration_date})

      assert subscription.expires_on == NaiveDateTime.to_date(new_expiration_date)
    end

    test "returns an error changeset with invalid update", %{user: user, date: date} do
      attrs = %{user_id: user.id, store: :stripe, expires_on: date}

      assert {:ok, sub} = Subscriptions.create(attrs)

      assert {:error, %{}} = Subscriptions.update(sub, %{store: :fruit_stand})
    end
  end

  describe "get/1" do
    test "updates a subscription with valid attributes", %{user: user, date: date} do
      attrs = %{user_id: user.id, store: :stripe, expires_on: date}

      assert {:ok, %{id: id} = sub} = Subscriptions.create(attrs)

      assert sub == Subscriptions.get(id)
    end
  end

  describe "get_stripe_customer_id/1" do
    test "returns stripe customer ID for non-subbed user with a Stripe customer already", %{
      user: user
    } do
      expect(Stripe.Customer, :search, fn _ ->
        {:ok, %{data: [%{id: "cus_12345"}]}}
      end)

      assert {:ok, "cus_12345"} == Subscriptions.get_stripe_customer_id(user)
    end

    test "returns stripe customer ID for non-subbed user with multiple Stripe customers already",
         %{user: user} do
      expect(Stripe.Customer, :search, fn _ ->
        {:ok, %{data: [%{id: "cus_12345"}, %{id: "cus_67890"}]}}
      end)

      assert {:ok, "cus_12345"} == Subscriptions.get_stripe_customer_id(user)
    end

    test "returns stripe customer ID for subscribed user", %{date: date, user: user} do
      # Create a subscription for the user
      Subscriptions.create(%{
        expires_on: date,
        user_id: user.id,
        store: :stripe,
        store_customer_id: "cus_987654"
      })

      reject(Stripe.Customer, :search, 1)

      assert {:ok, "cus_987654"} = Subscriptions.get_stripe_customer_id(user)
    end

    # What do we want to have happen here... if the user doesn't have a stripe sub, we should error or something
    # and display a message in the dashboard that they need to manage their sub elsewhere...
    test "returns stripe customer ID for a user subscribed to an app store", %{
      date: date,
      user: user
    } do
      Subscriptions.create(%{
        expires_on: date,
        user_id: user.id,
        store: :apple,
        store_customer_id: "apple_987654"
      })

      assert {:error, :not_found} == Subscriptions.get_stripe_customer_id(user)
    end
  end

  describe "create_or_update/1" do
    test "creates a subscription if one doesn't exist", %{date: date, user: user} do
      user = Repo.preload(user, :subscription)
      refute user.subscription

      assert {:ok, _subscription} =
               Subscriptions.create_or_update(%{
                 expires_on: date,
                 store: :stripe,
                 store_customer_id: "cus_12345",
                 user_id: user.id
               })
    end

    test "updates a subscription if one does exist", %{date: date, user: user} do
      assert {:ok, subscription1} =
               Subscriptions.create_or_update(%{
                 expires_on: date,
                 store: :stripe,
                 store_customer_id: "cus_12345",
                 user_id: user.id
               })

      assert {:ok, subscription2} =
               Subscriptions.create_or_update(%{
                 expires_on: date,
                 store: :stripe,
                 store_customer_id: "cus_56789",
                 user_id: user.id
               })

      assert subscription1.id == subscription2.id
    end

    test "does not overwrite existing store_customer_id on update", %{date: date, user: user} do
      assert {:ok, subscription} =
               Subscriptions.create_or_update(%{
                 expires_on: date,
                 store: :stripe,
                 store_customer_id: "cus_12345",
                 user_id: user.id
               })

      assert subscription.store_customer_id == "cus_12345"

      new_date = Date.add(date, 30)

      assert {:ok, updated} =
               Subscriptions.create_or_update(%{
                 expires_on: new_date,
                 store: :stripe,
                 store_customer_id: user.id,
                 user_id: user.id
               })

      assert updated.id == subscription.id
      assert updated.store_customer_id == "cus_12345"
      assert updated.expires_on == new_date
    end

    test "sets store_customer_id on create when no prior subscription", %{date: date, user: user} do
      assert {:ok, subscription} =
               Subscriptions.create_or_update(%{
                 expires_on: date,
                 store: :apple,
                 store_customer_id: user.id,
                 user_id: user.id
               })

      assert subscription.store_customer_id == user.id
    end
  end
end
