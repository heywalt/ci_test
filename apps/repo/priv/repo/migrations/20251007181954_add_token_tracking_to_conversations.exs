defmodule Repo.Migrations.AddTokenTrackingToConversations do
  use Ecto.Migration

  def change do
    alter table(:conversation_messages) do
      add :input_tokens, :integer
      add :output_tokens, :integer
    end

    alter table(:conversations) do
      add :total_input_tokens, :integer, default: 0, null: false
      add :total_output_tokens, :integer, default: 0, null: false
    end
  end
end
