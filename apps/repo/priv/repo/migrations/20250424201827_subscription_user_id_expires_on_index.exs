defmodule Repo.Migrations.SubscriptionUserIdExpiresOnIndex do
  use Ecto.Migration

  def change do
    create index(:subscriptions, [:user_id, :expires_on])
  end
end
