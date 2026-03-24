defmodule Repo.Migrations.UniqueTaskIndex do
  use Ecto.Migration

  def change do
    create unique_index(:tasks, [:contact_id, :due_at, :description])
  end
end
