defmodule Repo.Migrations.AddUserTier do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :tier, :string
    end
  end
end
