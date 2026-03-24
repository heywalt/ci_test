defmodule Repo.Migrations.AddQualityMetadataToEndatoProjections do
  use Ecto.Migration

  def change do
    alter table(:projection_enrichments_endato) do
      add :quality_metadata, :map
    end
  end
end
