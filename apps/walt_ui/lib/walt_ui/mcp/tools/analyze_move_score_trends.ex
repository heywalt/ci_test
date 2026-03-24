defmodule WaltUi.MCP.Tools.AnalyzeMoveScoreTrends do
  @moduledoc """
  Analyze Move Score (PTT) trends across a sample of contacts.
  Efficiently finds contacts whose scores have changed significantly over a time period.
  Uses random sampling of 500 contacts for performance.
  """

  use Anubis.Server.Component, type: :tool

  import Ecto.Query

  alias Repo
  alias WaltUi.Projections.Contact
  alias WaltUi.Projections.PttScore

  @sample_size 500

  schema do
    field :min_score_increase, :integer,
      required: false,
      description:
        "Minimum score increase to filter by (e.g., 30 points). Can be negative to find decreases."

    field :time_window_days, :integer,
      default: 90,
      description: "Number of days to look back for comparison (default: 90)"

    field :limit, :integer,
      default: 20,
      description: "Maximum number of results to return (default: 20)"
  end

  @impl true
  def execute(params, frame) do
    user_id = frame.assigns[:user_id]
    min_score_increase = Map.get(params, "min_score_increase")
    time_window_days = Map.get(params, "time_window_days", 90)
    limit = Map.get(params, "limit", 20)

    if is_nil(user_id) do
      {:error, "user_id is required in context"}
    else
      contacts = analyze_trends(user_id, min_score_increase, time_window_days, limit)

      {:ok,
       %{"contacts" => format_contacts(contacts, time_window_days), "sample_size" => @sample_size}}
    end
  end

  defp analyze_trends(user_id, min_score_increase, time_window_days, limit) do
    cutoff_date = NaiveDateTime.add(NaiveDateTime.utc_now(), -time_window_days, :day)

    sample_contacts = sample_contacts_with_scores(user_id)

    if Enum.empty?(sample_contacts) do
      []
    else
      sample_contacts
      |> compute_score_changes(cutoff_date)
      |> filter_by_min_increase(min_score_increase)
      |> Enum.sort_by(& &1.score_change, :desc)
      |> Enum.take(limit)
    end
  end

  defp sample_contacts_with_scores(user_id) do
    from(c in Contact,
      where: c.user_id == ^user_id and not is_nil(c.ptt),
      order_by: fragment("RANDOM()"),
      limit: ^@sample_size,
      select: %{
        id: c.id,
        first_name: c.first_name,
        last_name: c.last_name,
        email: c.email,
        phone: c.phone,
        current_ptt: c.ptt
      }
    )
    |> Repo.all()
  end

  defp compute_score_changes(sample_contacts, cutoff_date) do
    contact_ids = Enum.map(sample_contacts, & &1.id)

    historical_scores =
      from(p in PttScore,
        where: p.contact_id in ^contact_ids and p.occurred_at <= ^cutoff_date,
        distinct: true,
        select: %{
          contact_id: p.contact_id,
          score:
            first_value(p.score)
            |> over(partition_by: p.contact_id, order_by: [desc: p.occurred_at])
        }
      )
      |> Repo.all()
      |> Map.new(fn h -> {h.contact_id, h.score} end)

    Enum.map(sample_contacts, fn contact ->
      previous_score = Map.get(historical_scores, contact.id, 0)
      score_change = contact.current_ptt - previous_score

      Map.merge(contact, %{
        previous_score: previous_score,
        score_change: score_change
      })
    end)
  end

  defp filter_by_min_increase(contacts, nil), do: contacts

  defp filter_by_min_increase(contacts, min_score_increase) do
    Enum.filter(contacts, fn c -> c.score_change >= min_score_increase end)
  end

  defp format_contacts(contacts, time_window_days) do
    Enum.map(contacts, fn contact ->
      %{
        "id" => contact.id,
        "name" => format_name(contact.first_name, contact.last_name),
        "email" => contact.email,
        "phone" => contact.phone,
        "current_score" => contact.current_ptt,
        "previous_score" => contact.previous_score,
        "score_change" => contact.score_change,
        "time_window_days" => time_window_days
      }
    end)
  end

  defp format_name(first_name, last_name) do
    [first_name, last_name]
    |> Enum.reject(&is_nil/1)
    |> Enum.join(" ")
    |> String.trim()
  end
end
