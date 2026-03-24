defmodule Repo.Migrations.AddCalendars do
  use Ecto.Migration

  def change do
    create table(:calendars, primary_key: false) do
      add :id, :uuid, primary_key: true
      add :color, :string
      add :name, :string
      add :source_id, :string
      add :source, :string
      add :timezone, :string

      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all)

      timestamps()
    end

    create index(:calendars, [:id], unique: true)
    create index(:calendars, [:source_id], unique: true)
  end
end
