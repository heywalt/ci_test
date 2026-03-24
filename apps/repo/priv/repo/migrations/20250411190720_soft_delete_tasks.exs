defmodule Repo.Migrations.SoftDeleteTasks do
  use Ecto.Migration

  def change do
    alter table(:tasks) do
      add :is_deleted, :boolean, default: false
      add :is_expired, :boolean, default: false
    end

    create index(:tasks, [:user_id, :is_deleted, :is_expired])
    create index(:tasks, [:due_at])
  end
end
