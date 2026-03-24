defmodule WaltUi.MCP.Tools.SearchNotes do
  @moduledoc """
  Search through notes across all contacts.
  Returns matching notes with their associated contact information.
  """

  use Anubis.Server.Component, type: :tool

  require Logger

  alias WaltUi.Directory

  schema do
    field :query, :string, required: true, description: "Search term to find in notes"
    field :limit, :integer, default: 10, description: "Maximum number of results to return"
  end

  @impl true
  def execute(params, frame) do
    user_id = frame.assigns[:user_id]
    query = Map.get(params, "query", "")
    limit = Map.get(params, "limit", 10)

    Logger.info("SearchNotes called with query: #{inspect(query)}")

    case validate_user_id(user_id) do
      :ok ->
        results =
          user_id
          |> Directory.search_notes(query, limit: limit)
          |> Enum.map(&format_result/1)

        Logger.info("SearchNotes found #{length(results)} results")
        {:ok, %{"results" => results}}

      error ->
        error
    end
  end

  defp validate_user_id(nil), do: {:error, "user_id is required in context"}
  defp validate_user_id(_user_id), do: :ok

  defp format_result(note) do
    %{
      "note" => %{
        "id" => note.id,
        "content" => note.note,
        "created_at" => NaiveDateTime.to_iso8601(note.inserted_at)
      },
      "contact" => %{
        "id" => note.contact.id,
        "name" => format_name(note.contact),
        "email" => note.contact.email
      }
    }
  end

  defp format_name(contact) do
    [contact.first_name, contact.last_name]
    |> Enum.reject(&is_nil/1)
    |> Enum.join(" ")
    |> String.trim()
  end
end
