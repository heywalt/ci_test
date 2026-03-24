defmodule Repo.Migrations.AddQualityMetadataToFaradayProjections do
  use Ecto.Migration

  def change do
    alter table(:projection_enrichments_faraday) do
      add :quality_metadata, :map
    end
  end
end
