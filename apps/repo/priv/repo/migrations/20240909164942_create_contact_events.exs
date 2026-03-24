defmodule Repo.Migrations.CreateContactEvents do
  use Ecto.Migration

  def change do
    create table(:contact_events, primary_key: false) do
      add(:id, :uuid, primary_key: true, default: fragment("gen_random_uuid()"), null: false)
      add :type, :string
      add :event, :string

      add :contact_id, references(:contacts, type: :binary_id, on_delete: :delete_all)
      add :note_id, references(:notes, type: :binary_id, on_delete: :nothing)

      timestamps()
    end
  end
end
