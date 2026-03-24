defmodule Repo.Migrations.UpdateUserContactsFk do
  use Ecto.Migration

  def up do
    drop constraint(:contacts, "contacts_user_id_fkey")

    alter table(:contacts) do
      modify :user_id, references(:users, type: :binary_id, on_delete: :delete_all)
    end

    drop constraint(:properties, "properties_contact_id_fkey")

    alter table(:properties) do
      modify :contact_id, references(:contacts, type: :binary_id, on_delete: :delete_all)
    end

    drop constraint(:notes, "notes_contact_id_fkey")

    alter table(:notes) do
      modify :contact_id, references(:contacts, type: :binary_id, on_delete: :delete_all)
    end
  end

  def down do
    drop constraint(:contacts, "contacts_user_id_fkey")

    alter table(:contacts) do
      modify :user_id, references(:users, type: :binary_id, on_delete: :nothing)
    end

    drop constraint(:properties, "properties_contact_id_fkey")

    alter table(:properties) do
      modify :contact_id, references(:contacts, type: :binary_id, on_delete: :nothing)
    end

    drop constraint(:notes, "notes_contact_id_fkey")

    alter table(:notes) do
      modify :contact_id, references(:contacts, type: :binary_id, on_delete: :nothing)
    end
  end
end
