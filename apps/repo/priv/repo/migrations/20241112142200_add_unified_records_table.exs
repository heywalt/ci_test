defmodule Repo.Migrations.AddUnifiedRecordsTable do
  use Ecto.Migration

  def change do
    create table(:unified_contacts, primary_key: false) do
      add :id, :uuid, primary_key: true
      add :phone, :string

      timestamps()
    end

    create index(:unified_contacts, [:phone])

    alter table(:contacts) do
      add :unified_contact_id, references(:unified_contacts, type: :binary_id)
    end
  end
end
