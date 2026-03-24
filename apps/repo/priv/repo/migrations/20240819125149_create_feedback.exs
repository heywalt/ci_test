defmodule Repo.Migrations.CreateFeedback do
  use Ecto.Migration

  def change do
    create table(:feedbacks, primary_key: false) do
      add :id, :uuid, primary_key: true, default: fragment("gen_random_uuid()"), null: false

      add :contact_id, references(:contacts, type: :binary_id, on_delete: :delete_all)

      add :comment, :text

      timestamps()
    end
  end
end
