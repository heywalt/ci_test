defmodule Repo.Migrations.AddProjectionContactCreations do
  use Ecto.Migration

  def change do
    create table(:projection_contact_creations, primary_key: false) do
      add :id, :uuid, primary_key: true
      add :date, :date, null: false
      add :type, :string, null: false
      add :user_id, :uuid, null: false

      timestamps()
    end

    create index(:projection_contact_creations, [:date])
    create index(:projection_contact_creations, [:user_id])
  end
end
