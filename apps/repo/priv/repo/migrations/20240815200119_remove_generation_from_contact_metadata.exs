defmodule Repo.Migrations.RemoveGenerationFromContactMetadata do
  use Ecto.Migration

  def change do
    alter table("contact_metadata") do
      remove :generation, :string, default: ""
    end
  end
end
