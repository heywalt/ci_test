defmodule WaltUi.Conversations.ConversationMessage do
  @moduledoc false

  use Ecto.Schema
  import Ecto.Changeset

  alias WaltUi.Conversations.Conversation

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "conversation_messages" do
    field :role, Ecto.Enum, values: [:user, :model]
    field :content, :string
    field :input_tokens, :integer
    field :output_tokens, :integer

    belongs_to :conversation, Conversation

    timestamps(updated_at: false)
  end

  def changeset(message, attrs) do
    message
    |> cast(attrs, [:conversation_id, :role, :content, :input_tokens, :output_tokens])
    |> validate_required([:conversation_id, :role, :content])
  end
end
