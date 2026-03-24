defmodule Repo.Migrations.AddContactsUniqueKey do
  use Ecto.Migration

  def change do
    create unique_index(:contacts, [:user_id, :remote_id, :remote_source])
  end
end
