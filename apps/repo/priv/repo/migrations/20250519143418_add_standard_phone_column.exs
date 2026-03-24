defmodule Repo.Migrations.AddStandardPhoneColumn do
  use Ecto.Migration

  def change do
    alter table(:projection_contacts) do
      add :standard_phone, :string
    end

    create index(:projection_contacts, [:standard_phone])
  end
end
