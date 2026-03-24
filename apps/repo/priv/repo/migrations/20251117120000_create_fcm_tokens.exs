defmodule Repo.Migrations.CreateFcmTokens do
  use Ecto.Migration

  def change do
    create table(:fcm_tokens, primary_key: false) do
      add :id, :uuid, primary_key: true, default: fragment("gen_random_uuid()")
      add :user_id, references(:users, type: :uuid, on_delete: :delete_all), null: false
      add :token, :text, null: false

      timestamps()
    end

    create index(:fcm_tokens, [:user_id])
    create unique_index(:fcm_tokens, [:token])
  end
end
