defmodule Repo.Migrations.AddEnrichmentIdStandardPhoneIndex do
  use Ecto.Migration

  def change do
    create index(:projection_contacts, [:enrichment_id, :standard_phone])
  end
end
