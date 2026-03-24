defmodule Repo.Migrations.AddEmailIndexesToProjectionContacts do
  use Ecto.Migration

  def change do
    # Composite index for user_id + email lookups
    create index(:projection_contacts, [:user_id, :email])

    # GIN index for JSONB array email searches
    execute(
      "CREATE INDEX projection_contacts_emails_gin ON projection_contacts USING GIN (emails)",
      "DROP INDEX projection_contacts_emails_gin"
    )
  end
end
