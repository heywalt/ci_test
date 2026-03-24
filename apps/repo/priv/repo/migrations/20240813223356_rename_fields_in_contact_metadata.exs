defmodule Repo.Migrations.RenameFieldsInContactMetadata do
  use Ecto.Migration

  def change do
    rename table(:contact_metadata), :children_in_household, to: :has_children_in_household
    rename table(:contact_metadata), :number_of_grandchildren, to: :interest_in_grandchildren
    rename table(:contact_metadata), :propensity_probability, to: :propensity_to_transact

    alter table(:contact_metadata) do
      remove :has_pets_all, :string
    end
  end
end
