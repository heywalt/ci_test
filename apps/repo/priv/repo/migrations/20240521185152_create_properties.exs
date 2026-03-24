defmodule Repo.Migrations.CreateProperties do
  use Ecto.Migration

  def change do
    create table(:properties, primary_key: false) do
      add(:id, :uuid, primary_key: true, default: fragment("gen_random_uuid()"), null: false)
      add :estimated_value, :integer
      add :for_sale, :boolean

      add :address_id, references(:addresses, type: :binary_id, on_delete: :nothing)

      timestamps()
    end
  end
end
