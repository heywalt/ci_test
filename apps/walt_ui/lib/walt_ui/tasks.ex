defmodule WaltUi.Tasks do
  @moduledoc """
  The Task context.
  """
  import Ecto.Query, warn: false

  alias WaltUi.Tasks.Task

  @spec get(Ecto.UUID.t(), Keyword.t()) :: {:ok, Task.t()} | {:error, nil}
  def get(id, opts \\ []) do
    deleted? = Keyword.get(opts, :is_deleted, false)

    case Repo.get(Task, id) do
      nil ->
        {:error, nil}

      %{is_deleted: true} = task ->
        if deleted?, do: {:ok, task}, else: {:error, nil}

      task ->
        {:ok, task}
    end
  end

  @spec create(map()) :: {:ok, Task.t()} | {:error, Ecto.Changeset.t()}
  def create(attrs) do
    %Task{}
    |> Task.changeset(attrs)
    |> Repo.insert()
  end

  @spec list(Ecto.UUID.t(), Keyword.t()) :: list(Task.t())
  def list(user_id, opts \\ []) do
    deleted? = Keyword.get(opts, :is_deleted, false)
    expired? = Keyword.get(opts, :is_expired, false)

    Repo.all(
      from t in Task,
        where: t.user_id == ^user_id,
        where: t.is_deleted == ^deleted?,
        where: t.is_expired == ^expired?
    )
  end

  @spec update(Task.t(), map) :: {:ok, Task.t()} | {:error, Ecto.Changeset.t()}
  def update(task, attrs) do
    task
    |> Task.changeset(attrs)
    |> Repo.update()
  end

  @spec expire(Task.t()) :: {:ok, Task.t()} | {:error, Ecto.Changeset.t()}
  def expire(task) do
    __MODULE__.update(task, %{is_expired: true})
  end

  @spec complete(Task.t()) :: {:ok, Task.t()}
  def complete(task) do
    task
    |> Task.changeset(%{completed_at: DateTime.utc_now(), is_complete: true})
    |> Repo.update()
  end

  @spec uncomplete(Task.t()) :: {:ok, Task.t()}
  def uncomplete(task) do
    task
    |> Task.changeset(%{completed_at: nil, is_complete: false})
    |> Repo.update()
  end

  @spec delete(Task.t()) :: {:ok, Task.t()}
  def delete(task) do
    task
    |> Task.changeset(%{is_deleted: true})
    |> Repo.update()
  end
end
