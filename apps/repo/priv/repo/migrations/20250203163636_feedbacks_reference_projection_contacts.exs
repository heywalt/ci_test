defmodule Repo.Migrations.FeedbacksReferenceProjectionContacts do
  use Ecto.Migration

  def change do
    alter table(:feedbacks) do
      add :projection_id,
          references(:projection_contacts, type: :binary_id, on_delete: :delete_all)
    end
  end
end
