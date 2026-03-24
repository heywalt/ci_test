defmodule Repo.Migrations.AddQualityMetadataToTrestleProjections do
  use Ecto.Migration

  def change do
    alter table(:projection_enrichments_trestle) do
      add :quality_metadata, :map
    end
  end
end
