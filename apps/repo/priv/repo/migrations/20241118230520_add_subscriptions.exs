defmodule Repo.Migrations.AddSubscriptions do
  use Ecto.Migration

  def change do
    create table(:subscriptions, primary_key: false) do
      add :id, :uuid, primary_key: true, default: fragment("gen_random_uuid()"), null: false
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all)
      add :store_customer_id, :string
      add :store, :string
      add :expires_on, :date
      add :type, :string

      timestamps()
    end

    create index(:subscriptions, [:user_id])
  end
end
