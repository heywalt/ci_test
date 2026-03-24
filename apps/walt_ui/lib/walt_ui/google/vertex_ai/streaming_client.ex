defmodule WaltUi.Google.VertexAI.StreamingClient do
  @moduledoc """
  Streaming client for Google Vertex AI using Req.
  Supports Server-Sent Events (SSE) for real-time token streaming.
  """

  require Logger

  alias WaltUi.Google.VertexAI.Client

  @default_model "gemini-2.0-flash"

  @doc """
  Query Vertex AI with streaming response.

  Yields chunks as they arrive via a callback function.

  ## Options
    * `:model` - AI model to use (default: gemini-2.0-flash)
    * `:conversation_history` - Previous messages for context
    * `:on_chunk` - Callback function that receives each token chunk

  ## Example
      StreamingClient.query_stream("Hello", user_id,
        on_chunk: fn chunk -> IO.puts(chunk) end
      )
  """
  def query_stream(prompt, user_id, opts \\ []) do
    model = Keyword.get(opts, :model, @default_model)
    conversation_history = Keyword.get(opts, :conversation_history, [])
    on_chunk = Keyword.get(opts, :on_chunk, fn _chunk -> :ok end)

    with {:ok, token} <- get_auth_token(),
         tools <- Client.get_available_tools() do
      initial_contents = conversation_history ++ [Client.user_message(prompt)]
      execute_streaming_loop(token, initial_contents, model, user_id, tools, on_chunk)
    end
  end

  defp execute_streaming_loop(token, contents, model, user_id, tools, on_chunk, turn_count \\ 0) do
    if turn_count >= 5 do
      {:error, "Maximum conversation turns exceeded"}
    else
      request = Client.build_request_from_contents(contents, tools)

      case make_streaming_api_call(token, request, model, on_chunk) do
        {:ok, response} ->
          handle_streaming_response(
            response,
            token,
            contents,
            model,
            user_id,
            tools,
            on_chunk,
            turn_count
          )

        error ->
          error
      end
    end
  end

  defp handle_streaming_response(
         response,
         token,
         contents,
         model,
         user_id,
         tools,
         on_chunk,
         turn_count
       ) do
    Logger.debug("Handling streaming response: #{inspect(response)}")

    # Safely extract parts from response
    with %{"candidates" => [candidate | _]} <- response,
         %{"content" => content} <- candidate,
         %{"parts" => [first_part | _]} <- content do
      usage_metadata = response["usageMetadata"]

      case first_part do
        %{"functionCall" => function_call} ->
          # AI wants to call a function - pass errors back as response data
          result =
            case Client.execute_function_call(function_call, user_id) do
              {:ok, data} -> data
              {:error, reason} -> %{"error" => to_string(reason)}
            end

          updated_contents =
            contents ++
              [
                %{"role" => "model", "parts" => [%{"functionCall" => function_call}]},
                %{
                  "role" => "user",
                  "parts" => [
                    %{
                      "functionResponse" => %{
                        "name" => function_call["name"],
                        "response" => result
                      }
                    }
                  ]
                }
              ]

          # Continue loop with function result
          execute_streaming_loop(
            token,
            updated_contents,
            model,
            user_id,
            tools,
            on_chunk,
            turn_count + 1
          )

        %{"text" => text} ->
          # Final text response - already streamed to client
          {:ok, text, usage_metadata}

        _ ->
          {:error, "Unexpected response format: #{inspect(first_part)}"}
      end
    else
      _ ->
        {:error, "Invalid response structure: #{inspect(response)}"}
    end
  end

  defp make_streaming_api_call(access_token, request_body, model, on_chunk) do
    project_id = "heywalt"
    location = "us-east5"

    # Add alt=sse parameter to get Server-Sent Events format
    url =
      "https://#{location}-aiplatform.googleapis.com/v1/projects/#{project_id}/locations/#{location}/publishers/google/models/#{model}:streamGenerateContent?alt=sse"

    # Use :self to receive chunks as messages
    result =
      Req.post(url,
        json: request_body,
        auth: {:bearer, access_token},
        into: :self,
        receive_timeout: 60_000
      )

    case result do
      {:ok, %Req.Response{} = _response} ->
        # Collect all chunks from mailbox
        chunks = collect_stream_chunks(on_chunk)
        complete_response = aggregate_chunks(chunks)

        {:ok, complete_response}

      {:error, reason} ->
        {:error, "Streaming request failed: #{inspect(reason)}"}
    end
  end

  defp collect_stream_chunks(on_chunk, acc \\ []) do
    receive do
      {_, {:data, chunk}} ->
        Logger.debug("Received chunk: #{inspect(chunk)}")

        # Parse SSE chunk
        parsed_chunks =
          case parse_sse_chunk(chunk) do
            {:ok, parsed} ->
              Logger.debug("Parsed chunk: #{inspect(parsed)}")

              # Call the on_chunk callback for client streaming
              if parsed["candidates"] do
                candidate = List.first(parsed["candidates"])
                parts = get_in(candidate, ["content", "parts"]) || []

                Enum.each(parts, fn part ->
                  if text = part["text"] do
                    on_chunk.(text)
                  end
                end)
              end

              [parsed | acc]

            {:error, reason} ->
              Logger.debug("Failed to parse chunk: #{inspect(reason)}")
              acc
          end

        collect_stream_chunks(on_chunk, parsed_chunks)

      {_, :done} ->
        Logger.debug("Stream done, collected #{length(acc)} chunks")
        Enum.reverse(acc)

      other ->
        Logger.debug("Received other message: #{inspect(other)}")
        collect_stream_chunks(on_chunk, acc)
    after
      5_000 ->
        # Longer timeout for first chunk
        Logger.debug("Timeout, collected #{length(acc)} chunks")
        Enum.reverse(acc)
    end
  end

  defp parse_sse_chunk(chunk) when is_binary(chunk) do
    # SSE format: "data: {json}\n\n"
    chunk
    |> String.split("\n")
    |> Enum.find_value(&decode_sse_line/1)
    |> case do
      {:ok, data} -> {:ok, data}
      nil -> {:error, :no_data}
    end
  end

  defp parse_sse_chunk(_), do: {:error, :invalid_chunk}

  defp decode_sse_line(line) do
    case String.trim(line) do
      "data: " <> json_str ->
        case Jason.decode(json_str) do
          {:ok, data} -> {:ok, data}
          _ -> nil
        end

      _ ->
        nil
    end
  end

  defp aggregate_chunks([]), do: %{"candidates" => []}

  defp aggregate_chunks(chunks) do
    # Combine all text parts from all chunks
    all_parts =
      Enum.flat_map(chunks, fn chunk ->
        chunk
        |> get_in(["candidates", Access.at(0), "content", "parts"])
        |> List.wrap()
      end)

    # Merge text parts
    merged_text =
      all_parts
      |> Enum.filter(&Map.has_key?(&1, "text"))
      |> Enum.map_join("", & &1["text"])

    # Get function call if present (usually in last chunk)
    function_call =
      all_parts
      |> Enum.reverse()
      |> Enum.find_value(&Map.get(&1, "functionCall"))

    final_part =
      if function_call do
        %{"functionCall" => function_call}
      else
        %{"text" => merged_text}
      end

    # Get usage metadata from last chunk with complete token counts
    usage_metadata =
      chunks
      |> Enum.reverse()
      |> Enum.find_value(fn chunk ->
        case chunk["usageMetadata"] do
          %{"promptTokenCount" => _, "candidatesTokenCount" => _} = metadata -> metadata
          _ -> nil
        end
      end)

    base_response = %{
      "candidates" => [
        %{
          "content" => %{
            "parts" => [final_part]
          }
        }
      ]
    }

    if usage_metadata do
      Map.put(base_response, "usageMetadata", usage_metadata)
    else
      base_response
    end
  end

  defp get_auth_token do
    case Goth.fetch(WaltUi.Goth) do
      {:ok, token} -> {:ok, token.token}
      {:error, reason} -> {:error, "Auth failed: #{inspect(reason)}"}
    end
  end
end
