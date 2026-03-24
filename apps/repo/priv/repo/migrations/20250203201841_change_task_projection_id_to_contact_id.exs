defmodule Repo.Migrations.ChangeTaskProjectionIdToContactId do
  use Ecto.Migration

  def change do
    alter table(:tasks) do
      remove :contact_id, references(:contacts, type: :binary_id, on_delete: :delete_all)
    end

    rename table(:tasks), :projection_id, to: :contact_id
  end
end
