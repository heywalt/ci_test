defmodule Repo.Migrations.AddContactTags do
  use Ecto.Migration

  def change do
    create table(:contact_tags) do
      add :user_id, references(:users, on_delete: :delete_all), null: false

      add :contact_id, references(:projection_contacts, on_delete: :delete_all), null: false

      add :tag_id, references(:tags, on_delete: :delete_all), null: false

      timestamps()
    end

    create index(:contact_tags, [:id])
    create index(:contact_tags, [:user_id])
    create index(:contact_tags, [:contact_id])
    create index(:contact_tags, [:tag_id])
    create unique_index(:contact_tags, [:contact_id, :tag_id])
  end
end
