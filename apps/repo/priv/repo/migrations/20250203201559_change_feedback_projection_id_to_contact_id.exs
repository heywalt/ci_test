defmodule Repo.Migrations.ChangeFeedbackProjectionIdToContactId do
  use Ecto.Migration

  def change do
    alter table(:feedbacks) do
      remove :contact_id, references(:contacts, type: :binary_id, on_delete: :delete_all)
    end

    rename table(:feedbacks), :projection_id, to: :contact_id
  end
end
