defmodule Repo.Migrations.AddFailureStringToUnifiedContacts do
  use Ecto.Migration

  def change do
    alter table(:unified_contacts) do
      add :faraday_mismatch, :string, null: true
    end
  end
end
