defmodule Repo.Migrations.ChangeLikesTravelColumnType do
  use Ecto.Migration

  def up do
    execute """
     alter table contact_metadata alter column likes_travel type boolean using (likes_travel::boolean)
    """
  end

  def down do
    alter table(:contact_metadata) do
      modify :likes_travel, :string, from: :boolean
    end
  end
end
