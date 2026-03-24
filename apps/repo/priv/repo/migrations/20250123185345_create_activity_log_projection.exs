defmodule Repo.Migrations.CreateActivityLogProjection do
  use Ecto.Migration

  def change do
    create table(:projection_contact_activity_logs, primary_key: false) do
      add :id, :uuid, primary_key: true
      add :activity_type, :string
      add :contact_id, :uuid
      add :metadata, :jsonb, null: true
      add :user_id, references(:users, type: :binary_id, on_delete: :nothing)

      timestamps()
    end

    create index(:projection_contact_activity_logs, [:contact_id])
  end
end
