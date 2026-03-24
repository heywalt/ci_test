defmodule Repo.Migrations.AddGmailHistoryIdToExternalAccounts do
  use Ecto.Migration

  def change do
    alter table(:external_accounts) do
      add :gmail_history_id, :string
    end
  end
end
