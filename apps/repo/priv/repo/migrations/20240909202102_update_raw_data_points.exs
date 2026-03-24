defmodule Repo.Migrations.UpdateRawDataPoints do
  use Ecto.Migration

  def up do
    drop constraint(:raw_data_points, "raw_data_points_contact_id_fkey")

    alter table(:raw_data_points) do
      modify :contact_id, references(:contacts, type: :binary_id, on_delete: :delete_all),
        null: false
    end
  end

  def down do
    drop constraint(:raw_data_points, "raw_data_points_contact_id_fkey")

    alter table(:raw_data_points) do
      modify :contact_id, references(:contacts, type: :binary_id, on_delete: :nothing),
        null: false
    end
  end
end
