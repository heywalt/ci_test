defmodule Repo.Migrations.AddCqrsContactsTable do
  use Ecto.Migration

  def change do
    create table(:projection_contacts, primary_key: false) do
      add :id, :uuid, primary_key: true
      add :avatar, :string
      add :city, :string
      add :email, :string
      add :first_name, :string
      add :is_favorite, :boolean
      add :last_name, :string
      add :phone, :string
      add :ptt, :integer
      add :remote_id, :string
      add :remote_source, :string
      add :state, :string
      add :street_1, :string
      add :street_2, :string
      add :zip, :string

      add :unified_contact_id,
          references(:unified_contacts, type: :binary_id, on_delete: :nothing)

      add :user_id, references(:users, type: :binary_id, on_delete: :nothing)

      timestamps()
    end

    create index(:projection_contacts, [:unified_contact_id])
    create index(:projection_contacts, [:user_id])
    create unique_index(:projection_contacts, [:user_id, :remote_id, :remote_source])
  end
end
