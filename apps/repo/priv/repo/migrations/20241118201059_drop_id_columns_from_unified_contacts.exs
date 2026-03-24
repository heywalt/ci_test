defmodule Repo.Migrations.DropIdColumnsFromUnifiedContacts do
  use Ecto.Migration

  def change do
    alter table(:unified_contacts) do
      remove :endato_id
      remove :faraday_id
    end
  end
end
