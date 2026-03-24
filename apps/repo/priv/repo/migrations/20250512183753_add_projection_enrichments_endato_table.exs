defmodule Repo.Migrations.AddProjectionEnrichmentsEndatoTable do
  use Ecto.Migration

  def change do
    create table(:projection_enrichments_endato) do
      add :addresses, {:array, :map}, default: []
      add :emails, {:array, :string}, default: []
      add :first_name, :string
      add :last_name, :string
      add :phone, :string

      timestamps()
    end
  end
end
