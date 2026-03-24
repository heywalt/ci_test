defmodule Repo.Migrations.AddAddressesToContacts do
  use Ecto.Migration

  def change do
    alter table(:contacts) do
      add :address_id, references(:addresses, type: :binary_id, on_delete: :nothing)
    end

    create index(:contacts, [:address_id])
  end
end
