defmodule Repo.Migrations.AddEmbeddedPhonesAndEmails do
  use Ecto.Migration

  def change do
    alter table(:projection_contacts) do
      add :phone_numbers, {:array, :map}, default: []
      add :emails, {:array, :map}, default: []
    end
  end
end
