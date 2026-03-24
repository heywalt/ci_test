defmodule Repo.Migrations.AddTags do
  use Ecto.Migration

  def change do
    create table(:tags) do
      add :name, :string, null: false
      add :color, :string, null: false
      add :user_id, references(:users, on_delete: :delete_all), null: false

      timestamps()
    end

    create index(:tags, [:user_id])
    create index(:tags, [:name])
    create unique_index(:tags, [:user_id, :name])
  end
end
