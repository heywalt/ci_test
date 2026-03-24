defmodule WaltUi.Conversations do
  @moduledoc """
  Context for managing AI conversations and messages.
  """

  import Ecto.Query
  alias Ecto.Multi
  alias WaltUi.Conversations.Conversation
  alias WaltUi.Conversations.ConversationMessage

  @doc """
  Creates a new conversation with the initial user message in a single transaction.

  The title is derived from the first 50 characters of the prompt.

  ## Examples

      iex> create_conversation_with_message(user_id, "Which contacts are likely to move?")
      {:ok, %{conversation: %Conversation{}, message: %ConversationMessage{}}}

      iex> create_conversation_with_message(user_id, "")
      {:error, :conversation, %Ecto.Changeset{}, %{}}
  """
  def create_conversation_with_message(user_id, prompt) do
    title = String.slice(prompt, 0, 50)

    Multi.new()
    |> Multi.insert(:conversation, fn _ ->
      Conversation.changeset(%Conversation{}, %{user_id: user_id, title: title})
    end)
    |> Multi.insert(:message, fn %{conversation: conversation} ->
      ConversationMessage.changeset(%ConversationMessage{}, %{
        conversation_id: conversation.id,
        role: :user,
        content: prompt
      })
    end)
    |> Repo.transaction()
  end

  @doc """
  Gets a conversation by ID, verifying the user owns it.

  Returns `nil` if the conversation doesn't exist or belongs to another user.

  ## Examples

      iex> get_conversation(conversation_id, user_id)
      %Conversation{}

      iex> get_conversation(conversation_id, other_user_id)
      nil
  """
  def get_conversation(id, user_id) do
    Conversation
    |> where([c], c.id == ^id and c.user_id == ^user_id)
    |> Repo.one()
  end

  @doc """
  Gets a conversation with recent messages preloaded, verifying the user owns it.

  Messages are returned in reverse chronological order (most recent first).

  Returns `nil` if the conversation doesn't exist or belongs to another user.

  ## Options
    * `:limit` - Maximum number of messages to load (default: 20)

  ## Examples

      iex> get_conversation_with_messages(conversation_id, user_id)
      %Conversation{messages: [%ConversationMessage{}, ...]}

      iex> get_conversation_with_messages(conversation_id, user_id, limit: 10)
      %Conversation{messages: [%ConversationMessage{}, ...]}

      iex> get_conversation_with_messages(conversation_id, other_user_id)
      nil
  """
  def get_conversation_with_messages(id, user_id, opts \\ []) do
    limit = Keyword.get(opts, :limit, 20)

    messages_query =
      from m in ConversationMessage,
        order_by: [desc: m.inserted_at],
        limit: ^limit

    Conversation
    |> where([c], c.id == ^id and c.user_id == ^user_id)
    |> preload(messages: ^messages_query)
    |> Repo.one()
  end

  @doc """
  Adds a message to a conversation with optional token tracking.

  ## Examples

      iex> add_message(conversation_id, :user, "Tell me more", nil, nil)
      {:ok, %ConversationMessage{}}

      iex> add_message(conversation_id, :model, "Here's more...", 250, 120)
      {:ok, %ConversationMessage{}}

      iex> add_message(conversation_id, :invalid, "content", nil, nil)
      {:error, %Ecto.Changeset{}}
  """
  def add_message(conversation_id, role, content, input_tokens \\ nil, output_tokens \\ nil) do
    Multi.new()
    |> Multi.insert(:message, fn _ ->
      ConversationMessage.changeset(%ConversationMessage{}, %{
        conversation_id: conversation_id,
        role: role,
        content: content,
        input_tokens: input_tokens,
        output_tokens: output_tokens
      })
    end)
    |> Multi.run(:conversation, fn _repo, _changes ->
      if input_tokens || output_tokens do
        conversation = Repo.get(Conversation, conversation_id)

        conversation
        |> Conversation.increment_tokens_changeset(input_tokens, output_tokens)
        |> Repo.update()
      else
        {:ok, nil}
      end
    end)
    |> Repo.transaction()
    |> case do
      {:ok, %{message: message}} -> {:ok, message}
      {:error, :message, changeset, _} -> {:error, changeset}
      {:error, :conversation, changeset, _} -> {:error, changeset}
    end
  end

  @doc """
  Gets recent messages for a conversation, ordered chronologically (oldest first).

  ## Options
    * `:limit` - Maximum number of messages to return (default: 20)

  ## Examples

      iex> get_recent_messages(conversation_id)
      [%ConversationMessage{}, ...]

      iex> get_recent_messages(conversation_id, limit: 10)
      [%ConversationMessage{}, ...]
  """
  def get_recent_messages(conversation_id, opts \\ []) do
    limit = Keyword.get(opts, :limit, 20)

    ConversationMessage
    |> where([m], m.conversation_id == ^conversation_id)
    |> order_by([m], desc: m.inserted_at)
    |> limit(^limit)
    |> Repo.all()
    |> Enum.reverse()
  end

  @doc """
  Lists all conversations for a user, ordered by most recent activity.

  ## Examples

      iex> list_conversations(user_id)
      [%Conversation{}, ...]
  """
  def list_conversations(user_id) do
    Conversation
    |> where([c], c.user_id == ^user_id)
    |> order_by([c], desc: c.updated_at)
    |> Repo.all()
  end

  @doc """
  Deletes a conversation and all its messages.

  Returns `{:ok, %Conversation{}}` if successful, `{:error, :not_found}` if
  the conversation doesn't exist or belongs to another user.

  ## Examples

      iex> delete_conversation(conversation_id, user_id)
      {:ok, %Conversation{}}

      iex> delete_conversation(conversation_id, other_user_id)
      {:error, :not_found}
  """
  def delete_conversation(id, user_id) do
    case get_conversation(id, user_id) do
      nil ->
        {:error, :not_found}

      conversation ->
        Repo.delete(conversation)
    end
  end

  @doc """
  Converts messages to Vertex AI conversation history format.

  Messages are reversed to chronological order (oldest first) as required by Vertex AI.

  ## Examples

      iex> messages_to_history([%ConversationMessage{role: :user, content: "Hello"}])
      [%{"role" => "user", "parts" => [%{"text" => "Hello"}]}]
  """
  def messages_to_history(messages) do
    messages
    |> Enum.reverse()
    |> Enum.map(fn message ->
      %{
        "role" => to_string(message.role),
        "parts" => [%{"text" => message.content}]
      }
    end)
  end
end
