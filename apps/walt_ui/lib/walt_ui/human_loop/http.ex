defmodule WaltUi.HumanLoop.Http do
  @moduledoc """
  HTTP Client for interacting with HumanLoop.
  """
  require Logger

  def call_prompt(prompt_id, contact, user) do
    payload = build_payload(prompt_id, contact, user)

    client()
    |> Tesla.post("/prompts/call", payload)
    |> handle_response()
  end

  def list_prompts do
    client()
    |> Tesla.get("/prompts")
    |> handle_response()
  end

  defp config do
    Application.get_env(:walt_ui, WaltUi.HumanLoop)
  end

  defp client do
    middleware = [
      {Tesla.Middleware.BaseUrl, config()[:base_url]},
      Tesla.Middleware.JSON,
      {Tesla.Middleware.Headers,
       [
         {"Content-Type", "application/json"},
         {"X-API-KEY", config()[:api_key]}
       ]}
    ]

    adapter = Application.get_env(:tesla, :adapter, Tesla.Adapter.Hackney)
    Tesla.client(middleware, adapter)
  end

  defp build_payload(prompt_id, contact, user) do
    first_name = user_first_name(user.first_name)

    Jason.encode!(%{
      stream: false,
      id: prompt_id,
      messages: [
        %{
          # user, assistant, system, tool, developer
          role: "user",
          # Required to have this key as a string, even though it's empty.
          content: "",
          name: first_name
        }
      ],
      inputs: %{
        character_count: "140",
        tone: "friendly but professional",
        relationship: "known friend or acquaintance",
        contact_first_name: contact.first_name
      },
      metadata: %{},
      user: user.id
    })
  end

  defp handle_response({:ok, %{status: code, body: body}}) when code in 200..299 do
    message = body["logs"] |> hd |> then(fn log -> log["output"] end)

    {:ok, message}
  end

  defp handle_response({:ok, %{status: code}}) when code == 404 do
    Logger.warning("Prompt not found in HumanLoop.")

    {:error, :not_found}
  end

  defp handle_response({:ok, %{status: code}}) when code == 401 do
    Logger.warning("Unauthorized request to HumanLoop.")

    {:error, :unauthorized}
  end

  defp handle_response({:ok, response}) do
    Logger.warning("Unexpected Response from HumanLoop", details: inspect(response))

    {:error, :unexpected_response}
  end

  defp handle_response({:error, :timeout}) do
    Logger.warning("Request to HumanLoop timed out")

    {:error, :timeout}
  end

  defp handle_response({:error, reason}) do
    Logger.warning("Request to HumanLoop failed", error: inspect(reason))

    {:error, reason}
  end

  defp user_first_name(name) when is_binary(name) do
    name
    |> String.split(" ")
    |> List.first()
    |> to_string()
    |> String.trim()
  end

  defp user_first_name(_else), do: "None"
end
