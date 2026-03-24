defmodule WaltUi.Tasks.UpcomingDateTasksCronJobTest do
  use Repo.DataCase
  use Oban.Testing, repo: Repo

  import WaltUi.Factory

  alias WaltUi.Tasks.Task
  alias WaltUi.Tasks.UpcomingDateTasksCronJob

  describe "perform/1" do
    setup do
      today = Date.utc_today()
      ten_years_ago = Date.new!(today.year - 10, today.month, today.day)

      [
        eight_days: Date.add(ten_years_ago, 8),
        one_week: Date.add(ten_years_ago, 7),
        tomorrow: Date.add(ten_years_ago, 1),
        yesterday: Date.add(ten_years_ago, -1)
      ]
    end

    test "creates tasks for upcoming anniversaries", ctx do
      insert(:contact, anniversary: ctx.tomorrow)
      insert(:contact, anniversary: ctx.yesterday)
      insert(:contact, anniversary: ctx.one_week)
      insert(:contact, anniversary: ctx.eight_days)

      :ok = perform_job(UpcomingDateTasksCronJob, %{})

      assert [_one, _two] = Repo.all(Task)
    end

    test "creates upcoming anniversary tasks idempotently", ctx do
      insert(:contact, anniversary: ctx.one_week)

      :ok = perform_job(UpcomingDateTasksCronJob, %{})

      assert [_only_one] = Repo.all(Task)
    end

    test "creates tasks for upcoming birthdays", ctx do
      insert(:contact, birthday: ctx.tomorrow)
      insert(:contact, birthday: ctx.yesterday)
      insert(:contact, birthday: ctx.one_week)
      insert(:contact, birthday: ctx.eight_days)

      :ok = perform_job(UpcomingDateTasksCronJob, %{})

      assert [_one, _two] = Repo.all(Task)
    end

    test "creates upcoming birthday tasks idempotently", ctx do
      insert(:contact, birthday: ctx.tomorrow)

      :ok = perform_job(UpcomingDateTasksCronJob, %{})
      :ok = perform_job(UpcomingDateTasksCronJob, %{})

      assert [_only_one] = Repo.all(Task)
    end

    test "handles leap days" do
      leap_day = Date.new!(2000, 2, 29)
      insert(:contact, anniversary: leap_day)

      :ok = perform_job(UpcomingDateTasksCronJob, %{})

      assert [] = Repo.all(Task)
    end

    test "creates a Task due in the next 7 days", ctx do
      insert(:contact, birthday: ctx.one_week)

      :ok = perform_job(UpcomingDateTasksCronJob, %{})

      assert [task] = Repo.all(Task)
      assert NaiveDateTime.diff(task.due_at, NaiveDateTime.utc_now(), :day) >= 0
    end
  end
end
