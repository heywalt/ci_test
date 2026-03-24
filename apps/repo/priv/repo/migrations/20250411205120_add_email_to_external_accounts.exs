defmodule Repo.Migrations.AddEmailToExternalAccounts do
  use Ecto.Migration

  def change do
    alter table(:external_accounts) do
      add :email, :string
    end
  end
end
