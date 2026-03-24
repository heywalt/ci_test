defmodule Repo.Migrations.CreateContacts do
  use Ecto.Migration

  def change do
    create table(:contacts, primary_key: false) do
      add(:id, :uuid, primary_key: true, default: fragment("gen_random_uuid()"), null: false)
      add :user_id, references(:users, type: :binary_id, on_delete: :nothing)
      add :remote_source, :string
      add :remote_id, :string
      add :first_name, :string
      add :last_name, :string
      add :email, :string
      add :phone, :string
      add :avatar, :string
      add :description, :string

      timestamps()
    end

    create index(:contacts, [:user_id])
  end
end
