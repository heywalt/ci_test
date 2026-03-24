defmodule Repo.Migrations.AddIsHiddenToProjectionContacts do
  use Ecto.Migration

  def change do
    alter table(:projection_contacts) do
      add :is_hidden, :boolean, default: false, null: false
    end
  end
end
