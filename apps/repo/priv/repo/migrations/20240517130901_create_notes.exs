defmodule Repo.Migrations.CreateNotes do
  use Ecto.Migration

  def change do
    create table(:notes, primary_key: false) do
      add(:id, :uuid, primary_key: true, default: fragment("gen_random_uuid()"), null: false)

      add :note, :text

      timestamps()
    end
  end
end
