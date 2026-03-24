defmodule WaltUi.MCP.Tools.GetContactPttHistory do
  @moduledoc """
  Get PTT (Move Score) history for a specific contact.
  Returns historical score data normalized to weekly intervals.
  """

  use Anubis.Server.Component, type: :tool

  import Ecto.Query

  alias Repo
  alias WaltUi.Projections.Contact
  alias WaltUi.Projections.PttScore

  schema do
    field :contact_id, :string,
      required: true,
      description: "The ID of the contact to retrieve PTT history for"
  end

  @impl true
  def execute(params, frame) do
    user_id = frame.assigns[:user_id]
    contact_id = Map.get(params, "contact_id")

    cond do
      is_nil(user_id) ->
        {:error, "user_id is required in context"}

      is_nil(contact_id) ->
        {:error, "contact_id is required"}

      true ->
        get_ptt_history(user_id, contact_id)
    end
  end

  defp get_ptt_history(user_id, contact_id) do
    contact =
      from(c in Contact,
        where: c.id == ^contact_id and c.user_id == ^user_id
      )
      |> Repo.one()

    if contact do
      history =
        contact_id
        |> PttScore.ptt_history_query()
        |> Repo.all()
        |> PttScore.fill_history()

      {:ok, %{"history" => format_history(history)}}
    else
      {:error, "Contact not found"}
    end
  end

  defp format_history(scores) do
    Enum.map(scores, fn score ->
      %{
        "occurred_at" => NaiveDateTime.to_date(score.occurred_at) |> Date.to_iso8601(),
        "score" => score.score,
        "score_type" => to_string(score.score_type)
      }
    end)
  end
end
