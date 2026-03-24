defmodule Repo.Migrations.AddExternalAccountsTable do
  use Ecto.Migration

  def change do
    create table(:external_accounts, primary_key: false) do
      add :id, :uuid, primary_key: true, null: false
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false
      add :provider, :string
      add :provider_user_id, :string
      add :access_token, :string
      add :refresh_token, :string
      add :expires_at, :utc_datetime_usec
      timestamps()
    end

    create index(:external_accounts, [:user_id, :provider], unique: true)
  end
end
