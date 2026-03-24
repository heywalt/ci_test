defmodule WaltUi.Google.VertexAI.Client do
  @moduledoc """
  Client for Google Vertex AI API with function calling support.
  """

  require Logger

  alias WaltUi.MCP.Tools.AnalyzeMoveScoreTrends
  alias WaltUi.MCP.Tools.CreateNote
  alias WaltUi.MCP.Tools.GetContactDetails
  alias WaltUi.MCP.Tools.GetContactPttHistory
  alias WaltUi.MCP.Tools.GetContactTimeline
  alias WaltUi.MCP.Tools.SearchContacts
  alias WaltUi.MCP.Tools.SearchEmails
  alias WaltUi.MCP.Tools.SearchNotes
  alias WaltUi.Providers.WebSearch

  @default_model "gemini-2.0-flash"

  @tool_modules %{
    "search_contacts" => SearchContacts,
    "get_contact_details" => GetContactDetails,
    "get_contact_ptt_history" => GetContactPttHistory,
    "get_contact_timeline" => GetContactTimeline,
    "search_emails" => SearchEmails,
    "analyze_move_score_trends" => AnalyzeMoveScoreTrends,
    "create_note" => CreateNote,
    "search_notes" => SearchNotes
  }

  def query(prompt, user_id, opts \\ []) do
    model = Keyword.get(opts, :model, @default_model)
    conversation_history = Keyword.get(opts, :conversation_history, [])

    with {:ok, token} <- get_auth_token(),
         client <- client(token),
         tools <- get_available_tools() do
      # Prepend conversation history before new prompt
      initial_contents = conversation_history ++ [user_message(prompt)]
      execute_loop(client, initial_contents, model, user_id, tools)
    end
  end

  defp execute_loop(client, contents, model, user_id, tools, turn_count \\ 0) do
    if turn_count >= 5 do
      {:error, "Maximum conversation turns exceeded"}
    else
      request = build_request_from_contents(contents, tools)

      case make_api_call(client, request, model) do
        {:ok, response} ->
          handle_response(response, client, contents, model, user_id, tools, turn_count)

        error ->
          error
      end
    end
  end

  defp handle_response(response, client, contents, model, user_id, tools, turn_count) do
    candidate = List.first(response["candidates"])
    first_part = List.first(candidate["content"]["parts"])
    usage_metadata = response["usageMetadata"]

    case first_part do
      %{"functionCall" => function_call} ->
        handle_function_call(function_call, client, contents, model, user_id, tools, turn_count)

      %{"text" => text} ->
        {:ok, text, usage_metadata}

      _ ->
        {:error, "Unexpected response format: #{inspect(first_part)}"}
    end
  end

  defp handle_function_call(function_call, client, contents, model, user_id, tools, turn_count) do
    result =
      case execute_function_call(function_call, user_id) do
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

    execute_loop(client, updated_contents, model, user_id, tools, turn_count + 1)
  end

  @doc false
  def user_message(text) do
    %{"role" => "user", "parts" => [%{"text" => text}]}
  end

  @doc """
  Helper to build conversation history from previous messages.

  ## Example
      {:ok, response1} = query("Give me 3 contacts", user_id)
      history = build_history([
        {"user", "Give me 3 contacts"},
        {"model", response1}
      ])
      {:ok, response2} = query("Tell me more about Jason", user_id, conversation_history: history)
  """
  def build_history(messages) do
    Enum.map(messages, fn
      {"user", text} -> %{"role" => "user", "parts" => [%{"text" => text}]}
      {"model", text} -> %{"role" => "model", "parts" => [%{"text" => text}]}
    end)
  end

  defp get_auth_token do
    case Goth.fetch(WaltUi.Goth) do
      {:ok, token} -> {:ok, token.token}
      {:error, reason} -> {:error, "Auth failed: #{inspect(reason)}"}
    end
  end

  defp client(access_token) do
    project_id = "heywalt"
    location = "us-east5"

    base_url =
      "https://#{location}-aiplatform.googleapis.com/v1/projects/#{project_id}/locations/#{location}/publishers/google/models"

    middleware = [
      {Tesla.Middleware.BaseUrl, base_url},
      Tesla.Middleware.JSON,
      {Tesla.Middleware.BearerAuth, token: access_token},
      {Tesla.Middleware.Retry,
       delay: 1000,
       max_retries: 3,
       max_delay: 10_000,
       should_retry: fn
         {:ok, %{status: 429}} -> true
         {:ok, %{status: status}} when status >= 500 -> true
         {:error, _} -> true
         _ -> false
       end}
    ]

    adapter = Application.get_env(:tesla, :adapter, Tesla.Adapter.Hackney)
    Tesla.client(middleware, adapter)
  end

  @doc false
  def get_available_tools do
    [
      %{
        function_declarations: [
          %{
            name: "search_contacts",
            description:
              "Search and analyze contacts with enrichment data including life events (newly married/single, empty nester, retired), financial indicators (income, net worth, home equity), mortgage history, and property details. Returns contact IDs and summary data. Use broad searches (e.g., query='a' or query='') to analyze all contacts for predictive insights about moving likelihood, life changes, or market opportunities. IMPORTANT: Use this tool by default when a user asks about a contact, unless that contact is referenced earlier. IMPORTANT: This returns each contact's 'id' field which is the UUID needed for get_contact_details.",
            parameters: %{
              type: "object",
              properties: %{
                query: %{
                  type: "string",
                  description:
                    "Search term (name, email, or phone). Use a single letter like 'a' or empty string '' to search broadly across all contacts for analysis."
                },
                limit: %{
                  type: "integer",
                  description: "Maximum number of results to return (default: 10, max: 100)",
                  default: 10
                }
              },
              required: ["query"]
            }
          },
          %{
            name: "get_contact_details",
            description:
              "Get comprehensive details about a specific contact including notes, tags, full enrichment data, and interaction history. IMPORTANT: Requires the contact's UUID (from the 'id' field in search_contacts results), NOT the contact's name. If you only have a name, use search_contacts first to get the UUID.",
            parameters: %{
              type: "object",
              properties: %{
                contact_id: %{
                  type: "string",
                  description:
                    "The UUID of the contact (from the 'id' field in search results), NOT the contact name"
                }
              },
              required: ["contact_id"]
            }
          },
          %{
            name: "get_contact_ptt_history",
            description:
              "Get historical Move Score (PTT) data for a specific contact. Returns weekly score trends over the last 12 weeks, normalized to Sunday intervals. Each score includes the date, score value, and type (ptt or jitter). Use this to identify score trends, changes over time, and movement likelihood patterns. IMPORTANT: Requires the contact's UUID (from the 'id' field in search_contacts results).",
            parameters: %{
              type: "object",
              properties: %{
                contact_id: %{
                  type: "string",
                  description: "The UUID of the contact (from the 'id' field in search results)"
                }
              },
              required: ["contact_id"]
            }
          },
          %{
            name: "get_contact_timeline",
            description:
              "Get the interaction timeline for a contact including meetings, emails sent/received, and when the contact was created. Use this to answer questions like 'when did I last meet with X?' or 'when did I last email X?'. Returns chronologically ordered interactions (newest first) with details like meeting names, email subjects, and links. IMPORTANT: Requires the contact's UUID (from the 'id' field in search_contacts results).",
            parameters: %{
              type: "object",
              properties: %{
                contact_id: %{
                  type: "string",
                  description: "The UUID of the contact (from the 'id' field in search results)"
                },
                activity_type: %{
                  type: "string",
                  description:
                    "Optional filter: 'contact_invited' (meetings), 'contact_corresponded' (emails), or 'contact_created'"
                },
                limit: %{
                  type: "integer",
                  description: "Maximum results to return (default: 20)",
                  default: 20
                }
              },
              required: ["contact_id"]
            }
          },
          %{
            name: "search_emails",
            description:
              "Search for emails with a specific contact and return full email content. Use this to answer questions like 'when did I last hear from X?', 'summarize my emails with X', or 'what did X say?'. Can search by contact name OR fetch a specific email by message_id for follow-up questions. Returns email subject, date, direction (sent/received), and full body content.",
            parameters: %{
              type: "object",
              properties: %{
                contact_name: %{
                  type: "string",
                  description:
                    "Contact name to search for emails with. Use this for initial queries."
                },
                message_id: %{
                  type: "string",
                  description:
                    "Optional: Specific Gmail message ID to fetch directly. Use this for follow-up questions about a specific email."
                },
                limit: %{
                  type: "integer",
                  description: "Maximum number of emails to return (default: 5, max: 20)",
                  default: 5
                }
              },
              required: []
            }
          },
          %{
            name: "analyze_move_score_trends",
            description:
              "Analyze Move Score trends across a random sample of 500 contacts. Efficiently identifies contacts whose scores have increased or decreased significantly over a time period. Returns contacts sorted by score change, with current score, previous score, and the change amount. Use this to discover opportunities without querying every contact individually.",
            parameters: %{
              type: "object",
              properties: %{
                min_score_increase: %{
                  type: "integer",
                  description:
                    "Minimum score increase to filter by (e.g., 30 points). Can be negative to find decreases. If omitted, returns all contacts sorted by change."
                },
                time_window_days: %{
                  type: "integer",
                  description: "Number of days to look back for comparison (default: 90)",
                  default: 90
                },
                limit: %{
                  type: "integer",
                  description: "Maximum number of results to return (default: 20)",
                  default: 20
                }
              },
              required: []
            }
          },
          %{
            name: "create_note",
            description:
              "Create a note for a contact. Use this to record information about interactions, preferences, or any other relevant details about a contact. IMPORTANT: Requires the contact's UUID (from the 'id' field in search_contacts results). If you only have a name, use search_contacts first. If multiple contacts match, ask the user which one before creating the note.",
            parameters: %{
              type: "object",
              properties: %{
                contact_id: %{
                  type: "string",
                  description: "The UUID of the contact (from the 'id' field in search results)"
                },
                note: %{
                  type: "string",
                  description: "The note content to save"
                }
              },
              required: ["contact_id", "note"]
            }
          },
          %{
            name: "search_notes",
            description:
              "Search through all notes across all contacts. Use this to find contacts based on information recorded in notes, such as preferences, past conversations, or interests. For example: 'which contacts like basketball?' or 'who mentioned selling their house?'. Returns matching notes with their associated contact information.",
            parameters: %{
              type: "object",
              properties: %{
                query: %{
                  type: "string",
                  description: "Search term to find in notes"
                },
                limit: %{
                  type: "integer",
                  description: "Maximum number of results to return (default: 10)",
                  default: 10
                }
              },
              required: ["query"]
            }
          },
          %{
            name: "search_web",
            description:
              "Search the web for current information about real estate markets, mortgage rates, economic trends, news, regulations, or other time-sensitive data not available in the contact database. Returns web search results with titles, snippets, and URLs.",
            parameters: %{
              type: "object",
              properties: %{
                query: %{
                  type: "string",
                  description:
                    "The search query (e.g., 'current 30-year mortgage rates', 'real estate market trends 2025', 'housing affordability index')"
                },
                num_results: %{
                  type: "integer",
                  description: "Number of search results to return (default: 5, max: 10)",
                  default: 5
                }
              },
              required: ["query"]
            }
          }
        ]
      }
    ]
  end

  @doc false
  def build_request_from_contents(contents, tools) do
    %{
      contents: contents,
      system_instruction: %{
        parts: [%{text: get_system_instruction()}]
      },
      tools: tools,
      generation_config: %{
        temperature: 1.0,
        max_output_tokens: 2048
      }
    }
  end

  defp get_system_instruction do
    """
    You are a real estate CRM AI assistant with access to rich contact data and current web information.

    Your capabilities:
    - Search contacts by name, email, phone, or use broad searches to analyze all contacts
    - Access enrichment data: life events (marriages, divorces, retirement, empty nesters), financial indicators (income, net worth, home equity), mortgage history, property details
    - Search the web for current information: market trends, mortgage rates, real estate news, economic indicators
    - Identify contacts likely to move based on enrichment data and current market conditions
    - Provide actionable insights combining contact data with real-time market intelligence
    - Search and create notes (memories) about contacts

    Important: When the user mentions "memories" or asks about what they remember about contacts, use the search_notes tool to search through notes. Notes are the user's memories about their contacts.

    Important: When you don't have enough context to answer a question about contacts (e.g., "Which contact is my wife?", "Who is my accountant?", "Which contact likes golf?"), search notes FIRST before asking the user for clarification. Notes often contain personal details, relationships, preferences, and other context that can answer these questions.

    Important: Do not reference MCP Functions made available to you when asking permission to perform functions.
    Important: When returning contact information, always include the contact's id (UUID) in your response. This allows for easy follow-up queries and detailed lookups.
    Important: Format the contact id like this: (walt-contact-id: d7e97205-48f1-481c-9a09-5cdcd722bfcc)
    Important: Never ask the user for the contact_id. They do not know it.

    Important: When you retrieve emails using search_emails, ALWAYS include the email message IDs in your response text. Format like: (email-id: "123abc456"). This ensures you can reference them in follow-up queries since function call results are not persisted across conversation turns.

    Important: When the user asks to summarize or read a specific email (e.g., "summarize that email", "what did that email say?"), look for the message_id in your previous text response (the "(email-id:" you included). Use search_emails with that message_id parameter. NEVER ask the user for a message_id - they do not know it.

    Important: Whenever you are referencing "PTT Score", use the phrase "Move Score" instead.
    Important: When displaying the Move Score, divide by 10. For example, 94 should become 9.4.
    Important: When analyzing Move Score changes or finding contacts whose scores have changed the most, disregard 0 as a point of comparison. A score of 0 means no data, not an actual score.

    Be proactive: When asked analytical questions, search contacts and analyze the enrichment data to provide insights. Use web search for current market data, rates, or trends. Use contact tools for CRM data.
    """
  end

  defp make_api_call(client, request, model) do
    case Tesla.post(client, "/#{model}:generateContent", request,
           opts: [adapter: [recv_timeout: 60_000]]
         ) do
      {:ok, %{status: 200, body: body}} ->
        {:ok, body}

      {:ok, %{status: status, body: body}} ->
        {:error, "API call failed with status #{status}: #{inspect(body)}"}

      {:error, reason} ->
        {:error, "Request failed: #{inspect(reason)}"}
    end
  end

  @doc false
  def execute_function_call(function_call, user_id) do
    tool_name = function_call["name"]
    params = function_call["args"]
    frame = %{assigns: %{user_id: user_id}}

    case Map.fetch(@tool_modules, tool_name) do
      {:ok, module} ->
        module.execute(params, frame)

      :error ->
        execute_special_tool(tool_name, params)
    end
  end

  defp execute_special_tool("search_web", params) do
    WebSearch.search(params["query"], params["num_results"] || 5)
  end

  defp execute_special_tool(tool_name, _params) do
    {:error, "Unknown tool: #{tool_name}"}
  end
end
