defmodule Repo.Migrations.CreateAddresses do
  use Ecto.Migration

  def change do
    create table(:addresses, primary_key: false) do
      add(:id, :uuid, primary_key: true, default: fragment("gen_random_uuid()"), null: false)

      add :street_1, :string
      add :street_2, :string
      add :city, :string
      add :state, :string
      add :zip, :string

      timestamps()
    end
  end
end
