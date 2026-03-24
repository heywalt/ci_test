defmodule Repo.Migrations.ChangeContactPtt do
  use Ecto.Migration

  def change do
    alter table(:contacts) do
      modify :ppt, :float, from: :integer
    end

    rename table(:contacts), :ppt, to: :ptt
  end
end
