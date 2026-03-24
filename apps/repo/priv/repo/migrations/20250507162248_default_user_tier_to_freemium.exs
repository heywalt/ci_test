defmodule Repo.Migrations.DefaultUserTierToFreemium do
  use Ecto.Migration

  def up do
    alter table(:users) do
      modify :tier, :string, default: "freemium"
    end
  end

  def down do
    alter table(:users) do
      modify :tier, :string, default: nil
    end
  end
end
