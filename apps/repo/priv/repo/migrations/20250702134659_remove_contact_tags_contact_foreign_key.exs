defmodule Repo.Migrations.RemoveContactTagsContactForeignKey do
  use Ecto.Migration

  def up do
    drop constraint(:contact_tags, "contact_tags_contact_id_fkey")
  end

  def down do
    alter table(:contact_tags) do
      modify :contact_id,
             references(:projection_contacts, type: :binary_id, on_delete: :delete_all)
    end
  end
end
