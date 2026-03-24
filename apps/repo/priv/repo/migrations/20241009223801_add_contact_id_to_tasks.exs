defmodule Repo.Migrations.AddContactIdToTasks do
  use Ecto.Migration

  def change do
    alter table(:tasks) do
      add :contact_id, references(:contacts, type: :binary_id, on_delete: :nothing)
    end
  end
end
