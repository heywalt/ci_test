defmodule Repo.Migrations.AddStoreCustomerIdIndexToSubscriptions do
  use Ecto.Migration

  def change do
    create index(:subscriptions, [:store_customer_id], unique: true)
  end
end
