defmodule Repo.Migrations.MakeUnifiedContactPhoneUnique do
  use Ecto.Migration

  def change do
    drop index(:unified_contacts, [:phone])
    create unique_index(:unified_contacts, [:phone])
  end
end
