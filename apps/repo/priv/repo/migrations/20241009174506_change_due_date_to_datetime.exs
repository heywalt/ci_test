defmodule Repo.Migrations.ChangeDueDateToDatetime do
  use Ecto.Migration

  def up do
    alter table(:tasks) do
      modify :due_at, :naive_datetime
    end
  end

  def down do
    alter table(:tasks) do
      modify :due_at, :date
    end
  end
end
