defmodule Repo.Migrations.SimplifyAssociations do
  use Ecto.Migration

  def change do
    alter table(:properties) do
      add :contact_id, references(:contacts, type: :binary_id, on_delete: :nothing)
    end

    create index(:properties, [:contact_id])

    drop table("contacts_properties")

    alter table(:notes) do
      add :contact_id, references(:contacts, type: :binary_id, on_delete: :nothing)
    end

    create index(:notes, [:contact_id])

    drop table("contacts_notes")
  end
end
