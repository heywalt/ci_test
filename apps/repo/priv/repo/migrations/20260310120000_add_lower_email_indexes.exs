defmodule Repo.Migrations.AddLowerEmailIndexes do
  use Ecto.Migration

  def change do
    create index(:users, ["lower(email)"], name: :users_lower_email_idx)
    create index(:external_accounts, ["lower(email)"], name: :external_accounts_lower_email_idx)
  end
end
