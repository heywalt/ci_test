defmodule WaltUiWeb.Api.Controllers.TasksControllerTest do
  use WaltUiWeb.ConnCase

  import WaltUi.AccountFixtures

  alias WaltUi.Tasks

  setup %{conn: conn} do
    {:ok, conn: put_req_header(conn, "accept", "application/json")}
  end

  describe "List Tasks" do
    test "renders list of tasks for a given user", %{conn: conn} do
      user = user_fixture()

      result =
        conn
        |> authenticate_user(user)
        |> get(~p"/api/tasks")

      assert json_response(result, 200)["data"]
    end
  end

  describe "Create Tasks" do
    test "creates a task with the given attributes", %{conn: conn} do
      user = user_fixture()

      attrs = %{
        "description" => "Call Mike",
        "due_at" => "2024-10-05T00:00:00Z"
      }

      result =
        conn
        |> authenticate_user(user)
        |> post(~p"/api/tasks", attrs)

      response = json_response(result, 201)["data"]

      assert response["attributes"]["description"] == "Call Mike"
    end
  end

  describe "Update Tasks" do
    test "updates an existing task with the given attributes", %{conn: conn} do
      user = user_fixture()

      attrs = %{
        "description" => "Call Mike",
        "due_at" => "2024-10-05T00:00:00Z",
        "created_by" => "user",
        "user_id" => user.id
      }

      assert {:ok, %{description: "Call Mike"} = task} = Tasks.create(attrs)

      update_attrs = %{
        "description" => "Call Jaxon"
      }

      result =
        conn
        |> authenticate_user(user)
        |> put(~p"/api/tasks/#{task}", update_attrs)

      response = json_response(result, 200)["data"]

      assert response["attributes"]["description"] == "Call Jaxon"
    end
  end

  describe "Completing/uncompleting a Task" do
    test "updates an existing task to complete", %{conn: conn} do
      user = user_fixture()

      attrs = %{
        "description" => "Call Mike",
        "due_at" => "2024-10-05T00:00:00Z",
        "created_by" => "user",
        "user_id" => user.id
      }

      assert {:ok, %{description: "Call Mike", is_complete: false} = task} = Tasks.create(attrs)

      result =
        conn
        |> authenticate_user(user)
        |> put(~p"/api/tasks/#{task}/complete")

      response = json_response(result, 200)["data"]

      assert response["attributes"]["is_complete"] == true
    end

    test "updates an existing task to NOT complete", %{conn: conn} do
      user = user_fixture()

      attrs = %{
        "description" => "Call Mike",
        "due_at" => "2024-10-05T00:00:00Z",
        "created_by" => "user",
        "user_id" => user.id,
        "is_complete" => true
      }

      assert {:ok, %{description: "Call Mike", is_complete: true} = task} = Tasks.create(attrs)

      result =
        conn
        |> authenticate_user(user)
        |> put(~p"/api/tasks/#{task}/uncomplete")

      response = json_response(result, 200)["data"]

      assert response["attributes"]["is_complete"] == false
      assert is_nil(response["attributes"]["completed_at"])
    end
  end

  describe "Delete a Task" do
    test "deletes an existing task if it belongs to the current user", %{conn: conn} do
      user = user_fixture()

      attrs = %{
        "description" => "Call Mike",
        "due_at" => "2024-10-05T00:00:00Z",
        "created_by" => "user",
        "user_id" => user.id
      }

      assert {:ok, %{description: "Call Mike"} = task} = Tasks.create(attrs)

      result =
        conn
        |> authenticate_user(user)
        |> delete(~p"/api/tasks/#{task}")

      assert json_response(result, 200)
    end

    test "returns :unauthorized if user does not own the task being deleted", %{conn: conn} do
      user = user_fixture()
      other_user = user_fixture()

      attrs = %{
        "description" => "Call Mike",
        "due_at" => "2024-10-05T00:00:00Z",
        "created_by" => "user",
        "user_id" => user.id
      }

      assert {:ok, %{description: "Call Mike"} = task} = Tasks.create(attrs)

      result =
        conn
        |> authenticate_user(other_user)
        |> delete(~p"/api/tasks/#{task}")

      assert json_response(result, 401)
    end
  end
end
