defmodule Repo.Migrations.CreateUsers do
  use Ecto.Migration

  def change do
    create table(:users, primary_key: false) do
      add(:id, :uuid, primary_key: true, default: fragment("gen_random_uuid()"), null: false)
      add :auth_uid, :string
      add :first_name, :string
      add :last_name, :string
      add :email, :string
      add :bio, :string
      add :avatar, :string

      timestamps()
    end

    create unique_index(:users, :email)
  end
end
