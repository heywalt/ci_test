defmodule WaltUi.Projections.PttScoreTest do
  use Repo.DataCase, async: true

  import WaltUi.Factory

  alias WaltUi.Projections.PttScore

  describe "fill_history/2" do
    test "returns empty list if no ptt history" do
      assert PttScore.fill_history([]) == []
    end

    test "does NOT backfill past the oldest Move Score" do
      ptt = insert(:ptt_score)

      assert [%{id: id}] = PttScore.fill_history([ptt])
      assert id == ptt.id
    end

    test "fills gaps between now and the latest Move Score" do
      ptt =
        if Date.day_of_week(Date.utc_today()) == 7 do
          insert(:ptt_score, occurred_at: timestamp(-21))
        else
          insert(:ptt_score, occurred_at: timestamp(-14))
        end

      assert [old, mid, new] = PttScore.fill_history([ptt])

      # spaced by a week
      assert NaiveDateTime.diff(new.occurred_at, mid.occurred_at, :day) == 7
      assert NaiveDateTime.diff(mid.occurred_at, old.occurred_at, :day) == 7

      # all share the same score
      assert old.score == mid.score
      assert mid.score == new.score
    end

    test "fills gaps between Move Scores" do
      con = insert(:contact)
      old = insert(:ptt_score, contact_id: con.id, occurred_at: timestamp(-14), score: 14)
      new = insert(:ptt_score, contact_id: con.id, occurred_at: timestamp(0), score: 33)

      assert [old, gap, new] = PttScore.fill_history([new, old])

      assert old.score == 14
      assert gap.score == 14
      assert new.score == 33
    end

    test "prefers newer score if two scores normalize to the same sunday" do
      con = insert(:contact)
      old = insert(:ptt_score, contact_id: con.id, occurred_at: timestamp(-1), score: 14)
      new = insert(:ptt_score, contact_id: con.id, occurred_at: timestamp(-1), score: 33)

      assert [ptt] = PttScore.fill_history([new, old])
      assert ptt.id == new.id
      assert ptt.score == 33
    end

    test "normalizes timestamps to Sundays" do
      assert [ptt] = PttScore.fill_history([insert(:ptt_score)])
      assert ptt.occurred_at == sunday()
    end

    test "returns Move Scores in reverse order" do
      con = insert(:contact)
      old = insert(:ptt_score, contact_id: con.id, occurred_at: timestamp(-7))
      new = insert(:ptt_score, contact_id: con.id, occurred_at: timestamp(0))

      assert [a, b] = PttScore.fill_history([new, old])
      assert NaiveDateTime.compare(a.occurred_at, b.occurred_at) == :lt
    end
  end

  defp sunday do
    date = Date.utc_today()
    day = Date.day_of_week(date)
    to_sunday = if day == 7, do: 0, else: -day

    date
    |> Date.add(to_sunday)
    |> NaiveDateTime.new!(~T[00:00:00])
  end

  defp timestamp(days_from_now) do
    NaiveDateTime.utc_now()
    |> NaiveDateTime.add(days_from_now, :day)
    |> NaiveDateTime.truncate(:second)
  end
end
