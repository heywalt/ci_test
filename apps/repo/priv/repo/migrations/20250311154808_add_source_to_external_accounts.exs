defmodule Repo.Migrations.AddSourceToExternalAccounts do
  use Ecto.Migration

  def change do
    alter table(:external_accounts) do
      add :token_source, :string, null: false
    end
  end
end
