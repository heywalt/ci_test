defmodule Repo.Migrations.CreateProjectionGravatarTable do
  use Ecto.Migration

  def change do
    create table(:projection_enrichments_gravatar) do
      add :email, :string
      add :url, :string

      timestamps()
    end
  end
end
