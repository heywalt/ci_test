defmodule Repo.Migrations.AddConversations do
  use Ecto.Migration

  def change do
    create table(:conversations, primary_key: false) do
      add :id, :uuid, primary_key: true, default: fragment("gen_random_uuid()")
      add :user_id, references(:users, type: :uuid, on_delete: :delete_all), null: false
      add :title, :string, size: 255, null: false

      timestamps()
    end

    create index(:conversations, [:user_id])

    create table(:conversation_messages, primary_key: false) do
      add :id, :uuid, primary_key: true, default: fragment("gen_random_uuid()")

      add :conversation_id, references(:conversations, type: :uuid, on_delete: :delete_all),
        null: false

      add :role, :string, null: false
      add :content, :text, null: false

      timestamps(updated_at: false)
    end

    create index(:conversation_messages, [:conversation_id])
    create index(:conversation_messages, [:conversation_id, :inserted_at])
  end
end
