defmodule Repo.Migrations.CreateSessions do
  use Ecto.Migration

  def change do
    create table(:sessions, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all)
      add :auth_data, :map
      add :expires_at, :naive_datetime

      timestamps()
    end

    create index(:sessions, [:user_id])
    create index(:sessions, [:expires_at])
  end
end
