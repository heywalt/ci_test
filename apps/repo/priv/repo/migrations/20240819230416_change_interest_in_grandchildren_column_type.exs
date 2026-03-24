defmodule Repo.Migrations.ChangeInterestInGrandchildrenColumnType do
  use Ecto.Migration

  def change do
    execute """
     alter table contact_metadata alter column interest_in_grandchildren type boolean using (interest_in_grandchildren::boolean)
    """
  end

  def down do
    alter table(:contact_metadata) do
      modify :interest_in_grandchildren, :string, from: :boolean
    end
  end
end
