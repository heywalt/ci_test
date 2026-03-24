defmodule WaltUi.Tasks.ExpiredSystemTasksCronJobTest do
  @moduledoc false

  use Repo.DataCase
  use Oban.Testing, repo: Repo

  import WaltUi.Factory

  alias WaltUi.Tasks.ExpiredSystemTasksCronJob

  describe "perform/1" do
    test "expires tasks that are overdue by 3 days or more" do
      four_days_ago = NaiveDateTime.add(NaiveDateTime.utc_now(), -4, :day)
      task1 = insert(:task, due_at: four_days_ago)
      task2 = insert(:task, due_at: four_days_ago)

      refute task1.is_expired
      refute task2.is_expired

      :ok = perform_job(ExpiredSystemTasksCronJob, %{})

      assert Repo.reload(task1).is_expired
      assert Repo.reload(task2).is_expired
    end

    test "does not expire overdue tasks that are overdue by less than 3 days" do
      two_days_ago = NaiveDateTime.add(NaiveDateTime.utc_now(), -2, :day)
      task = insert(:task, due_at: two_days_ago)

      refute task.is_expired

      :ok = perform_job(ExpiredSystemTasksCronJob, %{})

      refute Repo.reload(task).is_expired
    end

    test "does not expire pending tasks" do
      task = insert(:task)

      refute task.is_expired

      :ok = perform_job(ExpiredSystemTasksCronJob, %{})

      refute Repo.reload(task).is_expired
    end

    test "does not expire completed tasks" do
      one_month_ago = NaiveDateTime.add(NaiveDateTime.utc_now(), -30, :day)
      task = insert(:task, due_at: one_month_ago, is_complete: true)

      refute task.is_expired

      :ok = perform_job(ExpiredSystemTasksCronJob, %{})

      refute Repo.reload(task).is_expired
    end

    test "does not expire deleted tasks" do
      one_month_ago = NaiveDateTime.add(NaiveDateTime.utc_now(), -30, :day)
      task = insert(:task, due_at: one_month_ago, is_deleted: true)

      refute task.is_expired

      :ok = perform_job(ExpiredSystemTasksCronJob, %{})

      refute Repo.reload(task).is_expired
    end
  end
end
