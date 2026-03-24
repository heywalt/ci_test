defmodule Repo.Migrations.NilifyOnUnifiedContactDelete do
  use Ecto.Migration

  def change do
    alter table(:contacts) do
      modify :unified_contact_id,
             references(:unified_contacts, type: :binary_id, on_delete: :nilify_all),
             from: references(:unified_contacts, type: :binary_id)
    end
  end
end
