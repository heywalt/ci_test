defmodule Repo.Migrations.AddGeolocationToProjectionContacts do
  use Ecto.Migration

  def change do
    alter table(:projection_contacts) do
      add :latitude, :decimal, precision: 10, scale: 6
      add :longitude, :decimal, precision: 10, scale: 6
    end

    create index(:projection_contacts, [:user_id, :latitude, :longitude])
  end
end
