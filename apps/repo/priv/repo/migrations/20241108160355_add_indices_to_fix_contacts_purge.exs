defmodule Repo.Migrations.AddIndicesToFixContactsPurge do
  use Ecto.Migration

  def change do
    create index(:contact_metadata, [:contact_id])
    create index(:raw_data_points, [:contact_id])
    create index(:contact_events, [:contact_id])
    create index(:feedbacks, [:contact_id])
    create index(:tasks, [:contact_id])
  end
end
