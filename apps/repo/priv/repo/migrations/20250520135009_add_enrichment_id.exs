defmodule Repo.Migrations.AddEnrichmentId do
  use Ecto.Migration

  def change do
    alter table(:projection_contacts) do
      add :enrichment_id, :uuid
    end

    create index(:projection_contacts, [:enrichment_id])
  end
end
