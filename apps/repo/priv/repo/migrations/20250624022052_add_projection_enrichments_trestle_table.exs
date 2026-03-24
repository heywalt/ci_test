defmodule Repo.Migrations.AddProjectionEnrichmentsTrestleTable do
  use Ecto.Migration

  def change do
    create table(:projection_enrichments_trestle) do
      add :addresses, {:array, :map}, default: []
      add :age_range, :string
      add :emails, {:array, :string}, default: []
      add :first_name, :string
      add :last_name, :string
      add :phone, :string

      timestamps()
    end

    create index(:projection_enrichments_trestle, [:phone])
  end
end
