defmodule WaltUi.TasksTest do
  use Repo.DataCase

  import WaltUi.Factory

  alias WaltUi.Tasks
  alias WaltUi.Tasks.Task

  setup do
    user = insert(:user)
    date = ~N[2024-10-09 11:17:46]

    {:ok, %{date: date, user: user}}
  end

  describe "get/1" do
    test "does not return deleted tasks unless specified" do
      %{id: task_1} = insert(:task)
      %{id: task_2} = insert(:task, is_deleted: true)

      assert {:ok, %Task{}} = Tasks.get(task_1)
      assert {:error, nil} = Tasks.get(Ecto.UUID.generate())
      assert {:error, nil} = Tasks.get(task_2)
      assert {:ok, %Task{}} = Tasks.get(task_2, is_deleted: true)
    end
  end

  describe "create/1" do
    test "creates a task from valid attrs", %{date: date, user: user} do
      attrs = %{
        description: "Test Task",
        created_by: :system,
        due_at: date,
        user_id: user.id
      }

      assert {:ok, %{description: "Test Task", created_by: :system, due_at: ^date}} =
               Tasks.create(attrs)
    end

    test "creates a task with a priority", %{date: date, user: user} do
      attrs = %{
        description: "Test Task",
        created_by: :system,
        due_at: date,
        user_id: user.id,
        priority: :high
      }

      assert {:ok, %{priority: :high}} = Tasks.create(attrs)
    end

    test "creates a task with a remind_at", %{date: date, user: user} do
      remind_at = DateTime.utc_now() |> DateTime.add(10, :day)

      attrs = %{
        description: "Test Task",
        created_by: :system,
        due_at: date,
        user_id: user.id,
        remind_at: remind_at
      }

      assert {:ok, %{remind_at: ^remind_at}} = Tasks.create(attrs)
    end

    test "returns an error changeset if missing a required attribute", %{date: date, user: user} do
      attrs = %{
        description: "Test Task",
        due_at: date,
        user_id: user.id
      }

      assert {:error, %{errors: [created_by: {"can't be blank", [validation: :required]}]}} =
               Tasks.create(attrs)
    end

    test "creates a task from valid attrs with an associated contact", %{date: date, user: user} do
      contact = insert(:contact, user_id: user.id)
      contact_id = contact.id

      attrs = %{
        description: "Test Task",
        created_by: :system,
        due_at: date,
        user_id: user.id,
        contact_id: contact.id
      }

      assert {:ok,
              %{
                description: "Test Task",
                contact_id: ^contact_id,
                created_by: :system,
                due_at: ^date
              }} = Tasks.create(attrs)
    end
  end

  describe "list/1" do
    test "lists all tasks for a given user", %{date: date, user: user} do
      attrs = %{
        description: "Test Task",
        created_by: :system,
        due_at: date,
        user_id: user.id
      }

      attrs2 = %{
        description: "Second Test Task",
        created_by: :system,
        due_at: date,
        user_id: user.id
      }

      Enum.map([attrs, attrs2], &Tasks.create(&1))

      assert [%Task{}, %Task{}] = Tasks.list(user.id)
    end

    test "does not return deleted tasks unless specified" do
      %{id: task_id, user_id: user_id} = insert(:task, is_deleted: true)

      assert [] = Tasks.list(user_id)
      assert [%Task{id: ^task_id}] = Tasks.list(user_id, is_deleted: true)
    end

    test "does not return expired tasks unless specified" do
      %{id: task_id, user_id: user_id} = insert(:task, is_expired: true)

      assert [] = Tasks.list(user_id)
      assert [%Task{id: ^task_id}] = Tasks.list(user_id, is_expired: true)
    end
  end

  describe "update/2" do
    test "updates an existing task", %{date: date, user: user} do
      attrs = %{
        description: "Test Task",
        created_by: :system,
        due_at: date,
        user_id: user.id
      }

      assert {:ok, task} = Tasks.create(attrs)

      assert {:ok, %Task{description: "Updated Task"}} =
               Tasks.update(task, %{description: "Updated Task"})
    end

    test "updates a task with a priority", %{date: date, user: user} do
      attrs = %{
        description: "Test Task",
        created_by: :system,
        due_at: date,
        user_id: user.id,
        priority: :high
      }

      assert {:ok, task} = Tasks.create(attrs)

      assert {:ok, %Task{priority: :high}} = Tasks.update(task, %{priority: :high})
    end

    test "updates a task with a remind_at", %{date: date, user: user} do
      remind_at = DateTime.utc_now() |> DateTime.add(10, :day)

      attrs = %{
        description: "Test Task",
        created_by: :system,
        due_at: date,
        user_id: user.id,
        remind_at: remind_at
      }

      assert {:ok, task} = Tasks.create(attrs)

      assert {:ok, %Task{remind_at: ^remind_at}} = Tasks.update(task, %{remind_at: remind_at})
    end
  end

  describe "complete/2" do
    test "updates an existing task", %{date: date, user: user} do
      attrs = %{
        description: "Test Task",
        created_by: :system,
        due_at: date,
        user_id: user.id
      }

      assert {:ok, %{is_complete: false} = task} = Tasks.create(attrs)

      assert {:ok, %Task{is_complete: true}} = Tasks.complete(task)
    end
  end

  describe "expire/1" do
    test "sets is_expired to true" do
      task = insert(:task, is_expired: false)
      assert {:ok, %Task{is_expired: true}} = Tasks.expire(task)
    end
  end

  describe "uncomplete/2" do
    test "sets a complete task to incomplete", %{date: date, user: user} do
      attrs = %{
        description: "Test Task",
        created_by: :system,
        due_at: date,
        user_id: user.id,
        is_complete: true
      }

      assert {:ok, %{is_complete: true} = task} = Tasks.create(attrs)

      assert {:ok, %Task{is_complete: false, completed_at: nil}} = Tasks.uncomplete(task)
    end
  end

  describe "delete/1" do
    test "soft deletes an existing task" do
      task = insert(:task)

      assert {:ok, %Task{}} = Tasks.delete(task)
      assert %Task{is_deleted: true} = Repo.get(Task, task.id)
    end
  end
end
