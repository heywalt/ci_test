defmodule WaltUi.Tasks.UpcomingDateTasksCronJob do
  @moduledoc """
  Oban job to find contacts with anniversaries and/or birthdays exactly 7 days from now.
  This job runs on a nightly cron schedule.
  """
  use Oban.Worker, queue: :tasks

  require Logger

  import Ecto.Query

  alias WaltUi.Projections.Contact
  alias WaltUi.Tasks

  @impl true
  def perform(_job) do
    now = NaiveDateTime.truncate(NaiveDateTime.utc_now(), :second)

    anniversary_attrs =
      contact_anniversary_query()
      |> Repo.all()
      |> Enum.map(&to_task(:anniversary, &1, now))

    birthday_attrs =
      contact_birthday_query()
      |> Repo.all()
      |> Enum.map(&to_task(:birthday, &1, now))

    Repo.insert_all(Tasks.Task, anniversary_attrs ++ birthday_attrs, on_conflict: :nothing)

    :ok
  end

  # We use the year from `CURRENT_DATE + 7` in case the next week crosses into a new year.
  # Leap days are turned into February 28 for sanity's sake.
  @upcoming_anniversaries """
  SELECT id,
         CASE
           WHEN date_part('month', anniversary) = 2 AND date_part('day', anniversary) = 29 THEN
             make_date(date_part('year', CURRENT_DATE + 7)::integer, 2, 28)
           ELSE
             make_date(date_part('year', CURRENT_DATE + 7)::integer, date_part('month', anniversary)::integer, date_part('day', anniversary)::integer)
         END AS upcoming
  FROM projection_contacts
  WHERE anniversary IS NOT NULL
  """

  defp contact_anniversary_query do
    Contact
    |> with_cte("upcoming_dates", as: fragment(@upcoming_anniversaries))
    |> upcoming_dates_query()
  end

  @upcoming_birthdays """
  SELECT id,
         CASE
           WHEN date_part('month', birthday) = 2 AND date_part('day', birthday) = 29 THEN
             make_date(date_part('year', CURRENT_DATE + 7)::integer, 2, 28)
           ELSE
             make_date(date_part('year', CURRENT_DATE + 7)::integer, date_part('month', birthday)::integer, date_part('day', birthday)::integer)
         END AS upcoming
  FROM projection_contacts
  WHERE birthday IS NOT NULL
  """

  defp contact_birthday_query do
    Contact
    |> with_cte("upcoming_dates", as: fragment(@upcoming_birthdays))
    |> upcoming_dates_query()
  end

  defp upcoming_dates_query(query) do
    now = Date.utc_today()
    week_from_now = Date.add(now, 7)

    query
    |> join(:inner, [con], ud in "upcoming_dates", on: ud.id == con.id, as: :ud)
    |> where([_con, ud: ud], ud.upcoming >= ^now)
    |> where([_con, ud: ud], ud.upcoming <= ^week_from_now)
    |> select([con, ud: _ud], con)
  end

  defp to_task(:anniversary, contact, timestamp) do
    %{
      contact_id: contact.id,
      created_by: :system,
      description: "Send an anniversary note to #{contact.first_name}",
      due_at: due_at(contact.anniversary),
      inserted_at: timestamp,
      updated_at: timestamp,
      user_id: contact.user_id
    }
  end

  defp to_task(:birthday, contact, timestamp) do
    %{
      contact_id: contact.id,
      created_by: :system,
      description: "Wish #{contact.first_name} a happy birthday",
      due_at: due_at(contact.birthday),
      inserted_at: timestamp,
      updated_at: timestamp,
      user_id: contact.user_id
    }
  end

  defp due_at(%{month: 2, day: 29}) do
    Date.utc_today()
    |> Timex.set(month: 2, day: 28)
    |> Timex.to_naive_datetime()
  end

  defp due_at(date) do
    today = Date.utc_today()
    due_date = Date.new!(today.year, date.month, date.day)

    if Date.diff(due_date, today) >= 0 do
      Timex.to_naive_datetime(due_date)
    else
      due_date
      |> Timex.shift(years: 1)
      |> Timex.to_naive_datetime()
    end
  end
end
