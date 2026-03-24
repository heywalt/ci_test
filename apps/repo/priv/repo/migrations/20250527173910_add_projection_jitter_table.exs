defmodule Repo.Migrations.AddProjectionJitterTable do
  use Ecto.Migration

  def change do
    create table(:projection_jitters) do
      add :ptt, :integer

      timestamps()
    end
  end
end
