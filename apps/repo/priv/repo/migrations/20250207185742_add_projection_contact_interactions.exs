defmodule Repo.Migrations.AddProjectionContactInteractions do
  use Ecto.Migration

  def change do
    create table(:projection_contact_interactions, primary_key: false) do
      add :id, :uuid, primary_key: true
      add :activity_type, :string
      add :contact_id, :uuid, null: false
      add :metadata, :jsonb, null: true
      add :occurred_at, :naive_datetime

      timestamps()
    end

    create index(:projection_contact_interactions, [:contact_id])
    create index(:projection_contact_interactions, [:occurred_at])
  end
end
