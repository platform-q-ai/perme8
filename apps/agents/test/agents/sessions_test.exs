defmodule Agents.SessionsTest do
  use Agents.DataCase, async: true

  alias Agents.Sessions
  alias Agents.Sessions.Domain.Entities.Task

  import Agents.Test.AccountsFixtures
  import Agents.SessionsFixtures

  describe "create_task/2" do
    test "creates a task and returns domain entity" do
      user = user_fixture()

      assert {:ok, %Task{} = task} =
               Sessions.create_task(%{
                 instruction: "Write tests",
                 user_id: user.id
               })

      assert task.instruction == "Write tests"
      assert task.status == "pending"
      assert task.user_id == user.id
    end

    test "returns error for blank instruction" do
      user = user_fixture()

      assert {:error, :instruction_required} =
               Sessions.create_task(%{instruction: "", user_id: user.id})
    end
  end

  describe "get_task/2" do
    test "returns domain entity for owned task" do
      user = user_fixture()
      task_schema = task_fixture(%{user_id: user.id})

      assert {:ok, %Task{} = task} = Sessions.get_task(task_schema.id, user.id)
      assert task.id == task_schema.id
    end

    test "returns not_found for other user's task" do
      user = user_fixture()
      other_user = user_fixture()
      task_schema = task_fixture(%{user_id: other_user.id})

      assert {:error, :not_found} = Sessions.get_task(task_schema.id, user.id)
    end
  end

  describe "list_tasks/1" do
    test "returns list of domain entities" do
      user = user_fixture()
      task_fixture(%{user_id: user.id, instruction: "Task 1"})
      task_fixture(%{user_id: user.id, instruction: "Task 2"})

      tasks = Sessions.list_tasks(user.id)

      assert length(tasks) == 2
      assert Enum.all?(tasks, &match?(%Task{}, &1))
    end

    test "returns empty list for user with no tasks" do
      user = user_fixture()
      assert [] == Sessions.list_tasks(user.id)
    end
  end

  describe "cancel_task/2" do
    test "returns error for non-existent task" do
      user = user_fixture()
      assert {:error, :not_found} = Sessions.cancel_task(Ecto.UUID.generate(), user.id)
    end

    test "returns error for completed task" do
      user = user_fixture()
      task = task_fixture(%{user_id: user.id, status: "completed"})

      assert {:error, :not_cancellable} = Sessions.cancel_task(task.id, user.id)
    end
  end
end
