defmodule Repo.Migrations.AddAlternateNamesToTrestle do
  use Ecto.Migration

  def change do
    alter table(:projection_enrichments_trestle) do
      add :alternate_names, {:array, :string}, default: []
    end
  end
end
