defmodule Repo.Migrations.AddHistoricalSyncMetadataToExternalAccounts do
  use Ecto.Migration

  def change do
    alter table(:external_accounts) do
      add :historical_sync_metadata, :map, default: %{}
    end
  end
end
