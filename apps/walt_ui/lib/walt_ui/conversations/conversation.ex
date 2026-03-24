defmodule WaltUi.Conversations.Conversation do
  @moduledoc false

  use Ecto.Schema
  import Ecto.Changeset

  alias WaltUi.Conversations.ConversationMessage

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "conversations" do
    field :title, :string
    field :user_id, :binary_id
    field :total_input_tokens, :integer, default: 0
    field :total_output_tokens, :integer, default: 0

    has_many :messages, ConversationMessage

    timestamps()
  end

  def changeset(conversation, attrs) do
    conversation
    |> cast(attrs, [:user_id, :title])
    |> validate_required([:user_id, :title])
    |> validate_length(:title, max: 255)
  end

  def increment_tokens_changeset(conversation, input_tokens, output_tokens) do
    conversation
    |> cast(%{}, [])
    |> put_change(
      :total_input_tokens,
      (conversation.total_input_tokens || 0) + (input_tokens || 0)
    )
    |> put_change(
      :total_output_tokens,
      (conversation.total_output_tokens || 0) + (output_tokens || 0)
    )
  end
end
