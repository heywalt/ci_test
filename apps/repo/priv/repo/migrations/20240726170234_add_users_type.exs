defmodule Repo.Migrations.AddUsersType do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :type, :string
    end
  end
end
