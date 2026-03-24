defmodule Repo.Migrations.AddIsFavoriteToContacts do
  use Ecto.Migration

  def change do
    alter table(:contacts) do
      add :is_favorite, :boolean, default: false
    end
  end
end
