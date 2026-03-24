defmodule Repo.Migrations.ChangeNoteProjectionIdToContactId do
  use Ecto.Migration

  def change do
    alter table(:notes) do
      remove :contact_id, references(:contacts, type: :binary_id, on_delete: :delete_all)
    end

    rename table(:notes), :projection_id, to: :contact_id
  end
end
