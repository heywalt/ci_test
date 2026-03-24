defmodule WaltUiWeb.Api.TasksController do
  use WaltUiWeb, :controller

  require Logger

  alias WaltUi.Tasks
  alias WaltUiWeb.Authorization

  action_fallback WaltUiWeb.FallbackController

  def index(conn, _params) do
    current_user = conn.assigns.current_user

    tasks = Tasks.list(current_user.id)

    conn
    |> put_view(WaltUiWeb.Api.TasksView)
    |> render(:index, %{data: tasks})
  end

  def create(conn, params) do
    current_user = conn.assigns.current_user

    params =
      params
      |> Map.put("user_id", current_user.id)
      |> Map.put("created_by", :user)

    with {:ok, task} <- Tasks.create(params) do
      conn
      |> put_status(:created)
      |> put_view(WaltUiWeb.Api.TasksView)
      |> render(:create, %{data: task})
    end
  end

  def update(conn, %{"id" => task_id} = params) do
    current_user = conn.assigns.current_user

    with {:ok, task} <- Tasks.get(task_id),
         {:ok, :authorized} <- Authorization.authorize(current_user, :update, task),
         {:ok, task} <- Tasks.update(task, params) do
      conn
      |> put_view(WaltUiWeb.Api.TasksView)
      |> render(:update, %{data: task})
    end
  end

  def complete(conn, %{"id" => task_id}) do
    current_user = conn.assigns.current_user

    with {:ok, task} <- Tasks.get(task_id),
         {:ok, :authorized} <- Authorization.authorize(current_user, :update, task),
         {:ok, task} <- Tasks.complete(task) do
      conn
      |> put_view(WaltUiWeb.Api.TasksView)
      |> render(:update, %{data: task})
    end
  end

  def uncomplete(conn, %{"id" => task_id}) do
    current_user = conn.assigns.current_user

    with {:ok, task} <- Tasks.get(task_id),
         {:ok, :authorized} <- Authorization.authorize(current_user, :update, task),
         {:ok, task} <- Tasks.uncomplete(task) do
      conn
      |> put_view(WaltUiWeb.Api.TasksView)
      |> render(:update, %{data: task})
    end
  end

  def delete(conn, %{"id" => task_id}) do
    current_user = conn.assigns.current_user

    with {:ok, task} <- Tasks.get(task_id),
         {:ok, :authorized} <- Authorization.authorize(current_user, :delete, task),
         {:ok, task} <- Tasks.delete(task) do
      conn
      |> put_view(WaltUiWeb.Api.TasksView)
      |> render(:update, %{data: task})
    end
  end
end
