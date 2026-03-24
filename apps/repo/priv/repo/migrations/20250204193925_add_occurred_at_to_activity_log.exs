defmodule Repo.Migrations.AddOccurredAtToActivityLog do
  use Ecto.Migration

  def change do
    alter table(:projection_contact_activity_logs) do
      add :occurred_at, :naive_datetime
    end

    create index(:projection_contact_activity_logs, [:occurred_at])
  end
end
