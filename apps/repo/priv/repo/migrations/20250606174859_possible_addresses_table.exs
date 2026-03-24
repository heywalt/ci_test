defmodule Repo.Migrations.PossibleAddressesTable do
  use Ecto.Migration

  def change do
    create table(:projection_possible_addresses) do
      add :enrichment_id, :uuid
      add :street_1, :string
      add :street_2, :string
      add :city, :string
      add :state, :string
      add :zip, :string

      timestamps()
    end
  end
end
