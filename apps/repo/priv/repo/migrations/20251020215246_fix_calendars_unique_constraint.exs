defmodule Repo.Migrations.FixCalendarsUniqueConstraint do
  use Ecto.Migration

  def change do
    # Drop the globally unique index on source_id
    drop index(:calendars, [:source_id])

    # Create a composite unique index on user_id + source_id
    # This allows multiple users to sync the same shared calendar
    create unique_index(:calendars, [:user_id, :source_id])
  end
end
