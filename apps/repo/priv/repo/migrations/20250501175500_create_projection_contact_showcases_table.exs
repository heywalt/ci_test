defmodule Repo.Migrations.CreateProjectionContactShowcasesTable do
  use Ecto.Migration

  def change do
    create table(:projection_contact_showcases) do
      add :contact_id, :uuid
      add :enrichment_type, :string
      add :user_id, :uuid

      timestamps()
    end

    create index(:projection_contact_showcases, [:contact_id])
    create index(:projection_contact_showcases, [:user_id])
  end
end
