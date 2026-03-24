defmodule Repo.Migrations.ChangeProjectionContactsUserId do
  use Ecto.Migration

  def change do
    alter table(:projection_contacts) do
      modify :user_id, :uuid,
        null: false,
        from: references(:users, type: :binary_id, on_delete: :nothing)
    end
  end
end
