defmodule Repo.Migrations.EventsReferenceProjectionContacts do
  use Ecto.Migration

  def change do
    alter table(:contact_events) do
      add :projection_id,
          references(:projection_contacts, type: :binary_id, on_delete: :delete_all)
    end
  end
end
