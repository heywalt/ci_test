defmodule Repo.Migrations.NotesReferenceProjectionContacts do
  use Ecto.Migration

  def change do
    alter table(:notes) do
      add :projection_id,
          references(:projection_contacts, type: :binary_id, on_delete: :delete_all)
    end
  end
end
