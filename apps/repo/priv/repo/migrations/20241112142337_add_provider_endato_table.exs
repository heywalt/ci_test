defmodule Repo.Migrations.AddProviderEndatoTable do
  use Ecto.Migration

  def change do
    create table(:provider_endato, primary_key: false) do
      add :id, :uuid, primary_key: true

      add :age, :integer
      add :city, :string
      add :email, :string
      add :first_name, :string
      add :last_name, :string
      add :middle_name, :string
      add :phone, :string
      add :state, :string
      add :street_1, :string
      add :street_2, :string

      add :unified_contact_id,
          references(:unified_contacts, type: :binary_id, on_delete: :delete_all)

      add :zip, :string

      timestamps()
    end

    create index(:provider_endato, [:unified_contact_id])

    alter table(:unified_contacts) do
      add :endato_id, references(:provider_endato, type: :binary_id)
    end
  end
end
