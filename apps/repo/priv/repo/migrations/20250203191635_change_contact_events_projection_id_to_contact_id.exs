defmodule Repo.Migrations.ChangeContactEventsProjectionIdToContactId do
  use Ecto.Migration

  def change do
    alter table(:contact_events) do
      remove :contact_id, references(:contacts, type: :binary_id, on_delete: :delete_all)
    end

    rename table(:contact_events), :projection_id, to: :contact_id
  end
end
