defmodule WaltUiWeb.Api.AIController do
  use WaltUiWeb, :controller

  alias WaltUi.AIUsage
  alias WaltUi.Contacts
  alias WaltUi.Conversations
  alias WaltUi.Google.VertexAI.Client
  alias WaltUi.Google.VertexAI.StreamingClient
  alias WaltUi.Projections.Contact

  @doc """
  Query the AI with optional streaming and conversation persistence support.

  Request body:
    {
      "prompt": "Your question here",
      "conversation_id": "uuid",        // Optional: continue existing conversation
      "new_conversation": true,         // Optional: create new conversation
      "conversation_history": [...]     // Optional: stateless history (legacy)
    }

  Headers:
    - Accept: text/event-stream  → Streaming response
    - Accept: application/json   → Standard JSON response
  """
  def query(conn, %{"prompt" => prompt} = params) do
    user_id = conn.assigns[:current_user].id
    contact_id = params["contact_id"]

    with :ok <- validate_contact(contact_id, user_id),
         :ok <- check_within_limit(user_id) do
      is_streaming = streaming?(conn)

      cond do
        params["new_conversation"] ->
          handle_new_conversation(conn, prompt, user_id, is_streaming, contact_id)

        params["conversation_id"] ->
          handle_existing_conversation(
            conn,
            prompt,
            user_id,
            params["conversation_id"],
            is_streaming,
            contact_id
          )

        true ->
          handle_stateless_query(conn, prompt, user_id, params, is_streaming, contact_id)
      end
    else
      {:error, :contact_not_found} ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "Contact not found"})

      {:error, :limit_exceeded} ->
        total_tokens_used = AIUsage.get_monthly_usage(user_id)
        monthly_limit = AIUsage.get_monthly_limit()

        conn
        |> put_status(:too_many_requests)
        |> json(%{
          error: "Monthly token limit exceeded",
          total_tokens_used: total_tokens_used,
          monthly_limit: monthly_limit
        })
    end
  end

  def query(conn, _params) do
    conn
    |> put_status(:bad_request)
    |> json(%{error: "prompt is required"})
  end

  @doc """
  Get the current user's monthly token usage and limit.

  Returns:
    {
      "total_tokens_used": 150000,
      "monthly_limit": 1000000
    }
  """
  def usage(conn, _params) do
    user_id = conn.assigns[:current_user].id
    total_tokens_used = AIUsage.get_monthly_usage(user_id)
    monthly_limit = AIUsage.get_monthly_limit()

    json(conn, %{
      total_tokens_used: total_tokens_used,
      monthly_limit: monthly_limit
    })
  end

  defp validate_contact(nil, _user_id), do: :ok

  defp validate_contact(contact_id, user_id) do
    if Contacts.contact_exists?(contact_id, user_id) do
      :ok
    else
      {:error, :contact_not_found}
    end
  end

  defp check_within_limit(user_id) do
    if AIUsage.within_limit?(user_id) do
      :ok
    else
      {:error, :limit_exceeded}
    end
  end

  defp streaming?(conn) do
    case get_req_header(conn, "accept") do
      ["text/event-stream" | _] -> true
      _ -> false
    end
  end

  defp handle_new_conversation(conn, prompt, user_id, is_streaming, contact_id) do
    case Conversations.create_conversation_with_message(user_id, prompt) do
      {:ok, %{conversation: conversation}} ->
        execute_query(conn, prompt, user_id, [], conversation.id, is_streaming, contact_id)

      {:error, _failed_operation, _failed_value, _changes} ->
        conn
        |> put_status(:internal_server_error)
        |> json(%{error: "Failed to create conversation"})
    end
  end

  defp handle_existing_conversation(
         conn,
         prompt,
         user_id,
         conversation_id,
         is_streaming,
         contact_id
       ) do
    case Conversations.get_conversation_with_messages(conversation_id, user_id) do
      nil ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "Conversation not found"})

      conversation ->
        Conversations.add_message(conversation_id, :user, prompt)
        history = Conversations.messages_to_history(conversation.messages)
        execute_query(conn, prompt, user_id, history, conversation_id, is_streaming, contact_id)
    end
  end

  defp handle_stateless_query(conn, prompt, user_id, params, is_streaming, contact_id) do
    conversation_history = Map.get(params, "conversation_history", [])
    execute_query(conn, prompt, user_id, conversation_history, nil, is_streaming, contact_id)
  end

  defp execute_query(
         conn,
         prompt,
         user_id,
         conversation_history,
         conversation_id,
         true,
         contact_id
       ) do
    # Prepend contact context if provided
    history_with_context = prepend_contact_context(conversation_history, contact_id, user_id)

    handle_streaming_query(
      conn,
      prompt,
      user_id,
      history_with_context,
      conversation_id
    )
  end

  defp execute_query(
         conn,
         prompt,
         user_id,
         conversation_history,
         conversation_id,
         false,
         contact_id
       ) do
    # Prepend contact context if provided
    history_with_context = prepend_contact_context(conversation_history, contact_id, user_id)

    handle_standard_query(
      conn,
      prompt,
      user_id,
      history_with_context,
      conversation_id
    )
  end

  defp prepend_contact_context(history, nil, _user_id), do: history

  defp prepend_contact_context(history, contact_id, user_id) do
    # Fetch contact (we know it exists from validation)
    contact = Repo.get_by!(Contact, id: contact_id, user_id: user_id)

    context_text = """
    You are currently viewing details for the following contact:

    Name: #{contact.first_name} #{contact.last_name}
    Email: #{contact.email}
    Phone: #{contact.phone}
    Move Score: #{if contact.ptt, do: contact.ptt / 10, else: "N/A"}
    Contact ID: #{contact.id}

    When the user uses pronouns like "their", "them", "they", or asks questions without specifying a name, they are referring to this contact.
    """

    [Client.user_message(context_text) | history]
  end

  defp handle_streaming_query(
         conn,
         prompt,
         user_id,
         conversation_history,
         conversation_id
       ) do
    conn =
      conn
      |> put_resp_content_type("text/event-stream")
      |> put_resp_header("cache-control", "no-cache")
      |> put_resp_header("connection", "keep-alive")
      |> send_chunked(200)

    # Send conversation_id immediately if present
    if conversation_id do
      event = %{type: "conversation_started", conversation_id: conversation_id}
      chunk(conn, "data: #{Jason.encode!(event)}\n\n")
    end

    # Accumulate full response for final event
    accumulated_text = :ets.new(:accumulated_text, [:set, :private])
    :ets.insert(accumulated_text, {:text, ""})

    result =
      StreamingClient.query_stream(prompt, user_id,
        conversation_history: conversation_history,
        on_chunk: fn chunk ->
          # Update accumulator
          [{:text, current}] = :ets.lookup(accumulated_text, :text)
          :ets.insert(accumulated_text, {:text, current <> chunk})

          # Send SSE token event
          event = %{type: "token", content: chunk}

          case chunk(conn, "data: #{Jason.encode!(event)}\n\n") do
            {:ok, conn} -> conn
            {:error, _} -> conn
          end
        end
      )

    # Clean up ETS table
    [{:text, full_text}] = :ets.lookup(accumulated_text, :text)
    :ets.delete(accumulated_text)

    case result do
      {:ok, _response, usage_metadata} ->
        # Save AI response to conversation if persistent
        if conversation_id do
          input_tokens = usage_metadata["promptTokenCount"]
          output_tokens = usage_metadata["candidatesTokenCount"]

          Conversations.add_message(
            conversation_id,
            :model,
            full_text,
            input_tokens,
            output_tokens
          )
        end

        # Get updated usage info
        total_tokens_used = AIUsage.get_monthly_usage(user_id)
        monthly_limit = AIUsage.get_monthly_limit()

        # Send done event with full text, conversation_id, and usage info
        done_event = %{
          type: "done",
          full_text: full_text,
          conversation_id: conversation_id,
          usage: %{
            total_tokens_used: total_tokens_used,
            monthly_limit: monthly_limit
          }
        }

        chunk(conn, "data: #{Jason.encode!(done_event)}\n\n")
        conn

      {:error, reason} ->
        error_event = %{type: "error", message: inspect(reason), conversation_id: conversation_id}
        chunk(conn, "data: #{Jason.encode!(error_event)}\n\n")
        conn
    end
  end

  defp handle_standard_query(
         conn,
         prompt,
         user_id,
         conversation_history,
         conversation_id
       ) do
    case Client.query(prompt, user_id, conversation_history: conversation_history) do
      {:ok, response, usage_metadata} ->
        # Save AI response to conversation if persistent
        if conversation_id do
          input_tokens = usage_metadata["promptTokenCount"]
          output_tokens = usage_metadata["candidatesTokenCount"]

          Conversations.add_message(
            conversation_id,
            :model,
            response,
            input_tokens,
            output_tokens
          )
        end

        # Get updated usage info
        total_tokens_used = AIUsage.get_monthly_usage(user_id)
        monthly_limit = AIUsage.get_monthly_limit()

        json(conn, %{
          content: response,
          conversation_id: conversation_id,
          usage: %{
            total_tokens_used: total_tokens_used,
            monthly_limit: monthly_limit
          }
        })

      {:error, reason} ->
        conn
        |> put_status(:internal_server_error)
        |> json(%{error: inspect(reason), conversation_id: conversation_id})
    end
  end
end
