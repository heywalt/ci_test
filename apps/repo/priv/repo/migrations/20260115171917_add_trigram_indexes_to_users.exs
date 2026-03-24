defmodule Repo.Migrations.AddTrigramIndexesToUsers do
  use Ecto.Migration

  def up do
    # Enable pg_trgm extension for trigram-based text search
    execute "CREATE EXTENSION IF NOT EXISTS pg_trgm"

    # Add GIN trigram indexes for efficient ILIKE searches
    execute "CREATE INDEX users_first_name_trgm_idx ON users USING GIN (first_name gin_trgm_ops)"
    execute "CREATE INDEX users_last_name_trgm_idx ON users USING GIN (last_name gin_trgm_ops)"
    execute "CREATE INDEX users_phone_trgm_idx ON users USING GIN (phone gin_trgm_ops)"
  end

  def down do
    execute "DROP INDEX IF EXISTS users_first_name_trgm_idx"
    execute "DROP INDEX IF EXISTS users_last_name_trgm_idx"
    execute "DROP INDEX IF EXISTS users_phone_trgm_idx"
    # Note: Not dropping pg_trgm extension as other tables may use it
  end
end
