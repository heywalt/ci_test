defmodule Repo.Migrations.AddProjectionPttScoresTable do
  use Ecto.Migration

  def change do
    create table(:projection_ptt_scores, primary_key: false) do
      add :id, :uuid, primary_key: true
      add :contact_id, :uuid, null: false
      add :occurred_at, :naive_datetime
      add :score, :integer
      add :score_type, :string

      timestamps()
    end

    create index(:projection_ptt_scores, [:contact_id])
    create index(:projection_ptt_scores, [:occurred_at])
  end
end
