defmodule Repo.Migrations.CreateRawDataPoints do
  use Ecto.Migration

  def change do
    create table(:raw_data_points, primary_key: false) do
      add :id, :uuid, primary_key: true, default: fragment("gen_random_uuid()"), null: false
      add :contact_id, references(:contacts, type: :binary_id, on_delete: :nothing), null: false
      add :source, :string
      add :property, :string
      add :value, :string

      timestamps()
    end
  end
end
