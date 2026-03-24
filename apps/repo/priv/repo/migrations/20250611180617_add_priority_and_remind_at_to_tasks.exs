defmodule Repo.Migrations.AddPriorityAndRemindAtToTasks do
  use Ecto.Migration

  def change do
    alter table(:tasks) do
      add :priority, :string, default: "none"
      add :remind_at, :utc_datetime_usec
    end
  end
end
