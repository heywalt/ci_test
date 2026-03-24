defmodule WaltUi.Tasks.ExpiredSystemTasksCronJob do
  @moduledoc """
  Oban job to find and expire overdue tasks.

  Overdue tasks are expired if they have a `created_by` value of `:system`
  and they're overdue by more than three days.
  """
  use Oban.Worker, queue: :tasks

  require Logger

  import Ecto.Query

  alias WaltUi.Tasks

  @impl true
  def perform(_job) do
    overdue_system_tasks_query()
    |> Repo.all()
    |> Enum.map(&Tasks.expire/1)
    |> Enum.each(fn
      {:ok, task} ->
        Logger.info("System task has expired", task_id: task.id)

      {:error, cs} ->
        Logger.warning("Failed to expire task", task_id: cs.data.id, details: inspect(cs.errors))
    end)
  end

  defp overdue_system_tasks_query do
    three_days_ago = Date.add(Date.utc_today(), -3)

    from t in Tasks.Task,
      where: t.created_by == :system,
      where: fragment("?::date < ?", t.due_at, ^three_days_ago),
      where: t.is_complete == false,
      where: t.is_deleted == false,
      where: t.is_expired == false
  end
end
