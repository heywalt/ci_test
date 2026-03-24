defmodule Repo.Migrations.CreateContactsProperties do
  use Ecto.Migration

  def change do
    create table(:contacts_properties, primary_key: false) do
      add(:id, :uuid, primary_key: true, default: fragment("gen_random_uuid()"), null: false)
      add :contact_id, references(:contacts, type: :binary_id, on_delete: :delete_all)
      add :property_id, references(:properties, type: :binary_id, on_delete: :delete_all)

      timestamps()
    end

    create index(:contacts_properties, [:contact_id])
  end
end
