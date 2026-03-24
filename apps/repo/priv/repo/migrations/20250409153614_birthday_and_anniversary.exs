defmodule Repo.Migrations.BirthdayAndAnniversary do
  use Ecto.Migration

  def change do
    alter table(:projection_contacts) do
      add :anniversary, :date
      add :birthday, :date
    end

    create index(:projection_contacts, [:anniversary])
    create index(:projection_contacts, [:birthday])
  end
end
