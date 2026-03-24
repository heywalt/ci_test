defmodule Repo.Migrations.UpdateTasksRelationship do
  use Ecto.Migration

  def change do
    alter table(:tasks) do
      add :projection_id,
          references(:projection_contacts, type: :binary_id, on_delete: :delete_all)
    end
  end
end
