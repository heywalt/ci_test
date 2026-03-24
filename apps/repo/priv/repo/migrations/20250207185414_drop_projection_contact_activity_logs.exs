defmodule Repo.Migrations.DropProjectionContactActivityLogs do
  use Ecto.Migration

  def change do
    drop table(:projection_contact_activity_logs), mode: :cascade
  end
end
