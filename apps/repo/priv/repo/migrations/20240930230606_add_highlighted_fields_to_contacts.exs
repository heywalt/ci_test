defmodule Repo.Migrations.AddHighlightedFieldsToContacts do
  use Ecto.Migration

  def change do
    alter table(:contacts) do
      add :highlighted_on, :date
      add :is_highlighted, :boolean, default: false
    end
  end
end
