defmodule Repo.Migrations.CreateHightlightTable do
  use Ecto.Migration

  def change do
    create table(:contact_highlights, primary_key: false) do
      add :id, :uuid, primary_key: true
      add :contact_id, references(:projection_contacts, type: :binary_id, on_delete: :delete_all)
      add :user_id, references(:users, type: :binary_id, on_delete: :nothing)

      timestamps()
    end

    create index(:contact_highlights, [:contact_id])
    create index(:contact_highlights, [:user_id])
  end
end
