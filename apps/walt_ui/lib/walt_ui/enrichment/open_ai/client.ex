defmodule WaltUi.Enrichment.OpenAi.Client do
  @moduledoc """
  Context for interacting with OpenAI API.
  """
  @behaviour WaltUi.Enrichment.OpenAi

  alias WaltUi.Error

  @impl true
  def confirm_identity(possible_match, identity) do
    identity
    |> identity_match_query(possible_match)
    |> query_open_ai()
    |> handle_response()
  end

  @impl true
  def contact_matches_data(contact, data) do
    contact
    |> contact_match_query(data)
    |> query_open_ai()
    |> handle_response()
  end

  defp query_open_ai(messages) do
    OpenAI.chat_completion(
      model: "gpt-4o-mini",
      messages: messages,
      temperature: 0.4
    )
  end

  defp identity_match_query(identity, possible_match) do
    # Extract alternate names from possible_match
    alternate_names = Map.get(possible_match, :alternate_names, [])

    # Format alternate names section
    alternate_names_section =
      case alternate_names do
        names when is_list(names) and length(names) > 0 ->
          formatted_names = Enum.join(names, ", ")
          "\nService alternate names: #{formatted_names}"

        _ ->
          "\nService alternate names: none"
      end

    # Clean service name (remove alternate_names key)
    clean_service_name = Map.drop(possible_match, [:alternate_names])

    [
      %{
        role: "system",
        content: ~s|
You are helping determine if a contact name matches data from an enrichment service.

TASK: Compare a user's contact name against enrichment service data and determine if they likely refer to the same person.

DATA TO COMPARE:
Contact name: #{Jason.encode!(identity)}
Service primary name: #{Jason.encode!(clean_service_name)}#{alternate_names_section}

MATCHING CRITERIA:
- Consider common nickname variations (William/Bill, Robert/Bob, Elizabeth/Liz, etc.)
- Consider formal vs informal versions (Michael/Mike, Christopher/Chris, etc.)
- Consider cultural name variations and shortened forms
- Names should match reasonably well - don't force matches for completely different names
- Both first AND last names should align (accounting for variations)

EXAMPLES:
Example 1 - Match: Contact "Bill Smith" vs Service "William Smith" with alternates [] → "likely match"
Example 2 - Mismatch: Contact "John Doe" vs Service "Jane Smith" with alternates ["J. Smith"] → "likely mismatch"
Example 3 - Match: Contact "Bob Johnson" vs Service "Alexander Johnson" with alternates ["Bob Johnson", "Bobby Johnson"] → "likely match"

INSTRUCTIONS:
Determine if the contact name and service data likely refer to the same person.
Respond with exactly one of these phrases: "likely match" or "likely mismatch"
Do not include any explanation or additional text.
        |
      }
    ]
  end

  defp contact_match_query(contact, data) do
    {:ok, cont} = contact_to_prompt(contact)
    {:ok, data} = Jason.encode(data)

    [
      %{
        role: "system",
        content:
          "I have a name, phone and email from a user's contact book, and some data from a contact matching service returned based on that contact's phone number. It is possible that the name from the contact book is a nickname, or contains a maiden name.

        contact json: #{cont}
        service json: #{data}

        Please make your response one of the following, and nothing else: likely match or likely mismatch"
      }
    ]
  end

  defp contact_to_prompt(contact) do
    contact
    |> Map.take([:first_name, :last_name, :phone, :email])
    |> Enum.reject(fn {_, v} -> is_nil(v) end)
    |> Map.new()
    |> Jason.encode()
  end

  defp handle_response(response) do
    case response do
      {:ok, %{choices: choices}} ->
        choice = List.first(choices)
        %{"message" => %{"content" => content}} = choice

        {:ok, String.starts_with?(content, "likely match")}

      {:error, error} when error in [:checkout_timeout, :timeout] ->
        Error.new("OpenAI request timeout", details: error)

      error ->
        Error.new("Unknown OpenAI Error", details: error)
    end
  end
end
