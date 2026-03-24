defmodule Repo.Migrations.CreateContactsNotes do
  use Ecto.Migration

  def change do
    create table(:contacts_notes, primary_key: false) do
      add(:id, :uuid, primary_key: true, default: fragment("gen_random_uuid()"), null: false)
      add :contact_id, references(:contacts, type: :binary_id, on_delete: :nothing)
      add :note_id, references(:notes, type: :binary_id, on_delete: :nothing)

      timestamps()
    end

    create index(:contacts_notes, [:contact_id])
  end
end
