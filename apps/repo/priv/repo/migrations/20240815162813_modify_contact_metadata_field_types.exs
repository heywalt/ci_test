defmodule Repo.Migrations.ModifyContactMetadataFieldTypes do
  use Ecto.Migration

  def up do
    execute """
     alter table contacts alter column ptt type integer using (ptt::integer)
    """

    execute """
     alter table contact_metadata alter column propensity_to_transact type integer using (propensity_to_transact::integer)
    """

    execute """
     alter table contact_metadata alter column has_basement type boolean using (has_basement::boolean)
    """

    execute """
     alter table contact_metadata alter column has_children_in_household type boolean using (has_children_in_household::boolean)
    """

    execute """
     alter table contact_metadata alter column has_pet type boolean using (has_pet::boolean)
    """

    execute """
     alter table contact_metadata alter column has_pool type boolean using (has_pool::boolean)
    """
  end

  def down do
    execute """
     alter table contacts alter column ptt type float using (ptt::float)
    """

    execute """
     alter table contact_metadata alter column propensity_to_transact type float using (propensity_to_transact::float)
    """

    alter table(:contact_metadata) do
      modify :has_basement, :string, from: :boolean
      modify :has_children_in_household, :string, from: :boolean
      modify :has_pet, :string, from: :boolean
      modify :has_pool, :string, from: :boolean
    end
  end
end
