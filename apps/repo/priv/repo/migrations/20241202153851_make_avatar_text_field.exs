defmodule Repo.Migrations.MakeAvatarTextField do
  use Ecto.Migration

  def change do
    alter table(:users) do
      modify :avatar, :text, from: :string
    end
  end
end
