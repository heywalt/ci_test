defmodule Repo.Migrations.AddTasks do
  use Ecto.Migration

  def change do
    create table(:tasks, primary_key: false) do
      add :id, :uuid, primary_key: true, default: fragment("gen_random_uuid()"), null: false
      add :description, :string
      add :is_complete, :boolean, default: false
      add :due_at, :date
      add :completed_at, :utc_datetime_usec
      add :created_by, :string

      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all)

      timestamps()
    end
  end
end
