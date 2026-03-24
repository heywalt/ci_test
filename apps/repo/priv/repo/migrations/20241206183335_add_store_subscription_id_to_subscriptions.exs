defmodule Repo.Migrations.AddStoreSubscriptionIdToSubscriptions do
  use Ecto.Migration

  def change do
    alter table(:subscriptions) do
      add :store_subscription_id, :string
    end
  end
end
