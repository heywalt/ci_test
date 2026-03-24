defmodule WaltUi.Projections.PttScore do
  @moduledoc false

  use Repo.WaltSchema

  import Ecto.Changeset
  import Ecto.Query

  @type t :: %__MODULE__{}

  @fields ~w(contact_id occurred_at score score_type)a

  @derive Jason.Encoder
  schema "projection_ptt_scores" do
    field :contact_id, :binary_id
    field :occurred_at, :naive_datetime
    field :score, :integer
    field :score_type, Ecto.Enum, values: [:jitter, :ptt]

    timestamps()
  end

  @spec changeset(t, map) :: Ecto.Changeset.t()
  def changeset(score \\ %__MODULE__{}, attrs) do
    score
    |> cast(attrs, @fields)
    |> validate_required(@fields)
  end

  @spec fill_history(scores :: [t], acc) :: acc when acc: [t]
  def fill_history(ptts, acc \\ [])

  def fill_history([], acc), do: acc

  def fill_history([x | xs], []) do
    ptt_sunday = to_sunday(x.occurred_at)
    now_sunday = to_sunday(NaiveDateTime.utc_now())

    if NaiveDateTime.diff(now_sunday, ptt_sunday, :day) > 7 do
      gap_ptt = %{x | occurred_at: now_sunday}
      fill_history([x | xs], [gap_ptt])
    else
      norm_ptt = %{x | occurred_at: ptt_sunday}
      fill_history(xs, [norm_ptt])
    end
  end

  def fill_history([x | xs], [y | ys] = acc) do
    ptt_sunday = to_sunday(x.occurred_at)
    new_sunday = to_sunday(y.occurred_at)

    case NaiveDateTime.diff(new_sunday, ptt_sunday, :day) do
      0 ->
        # normalized scores fall on the same sunday, so we prefer
        # the newest score chronologically
        norm_ptt = %{y | occurred_at: new_sunday}
        fill_history(xs, [norm_ptt | ys])

      diff when diff > 7 ->
        # normalized scores are greater than a week apart, so we
        # inject a gap score with the older score chronologically
        gap_sunday = NaiveDateTime.add(new_sunday, -7, :day)
        gap_ptt = %{x | occurred_at: gap_sunday}
        fill_history([x | xs], [gap_ptt | acc])

      _else ->
        # less than a week separates normalized scores, so we keep
        # the scores in the same order
        norm_ptt = %{x | occurred_at: ptt_sunday}
        fill_history(xs, [norm_ptt | acc])
    end
  end

  @spec ptt_history_query(Ecto.UUID.t()) :: Ecto.Query.t()
  def ptt_history_query(contact_id) do
    from ptt in WaltUi.Projections.PttScore,
      where: ptt.contact_id == ^contact_id,
      order_by: [desc: ptt.occurred_at],
      limit: 12
  end

  defp to_sunday(timestamp) do
    date = NaiveDateTime.to_date(timestamp)
    day = Date.day_of_week(date)
    days_since_sunday = if day == 7, do: 0, else: day

    date
    |> Date.add(-days_since_sunday)
    |> NaiveDateTime.new!(~T[00:00:00])
  end
end
