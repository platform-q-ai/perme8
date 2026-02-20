defmodule Agents.Sessions.Infrastructure.Repositories.TaskRepositoryTest do
  use Agents.DataCase, async: true

  alias Agents.Sessions.Infrastructure.Repositories.TaskRepository
  alias Agents.Sessions.Infrastructure.Schemas.TaskSchema
  alias Identity.Repo, as: Repo

  import Agents.Test.AccountsFixtures

  defp create_task(user, attrs \\ %{}) do
    default_attrs = %{
      instruction: "Write tests",
      user_id: user.id,
      status: "pending"
    }

    %TaskSchema{}
    |> TaskSchema.changeset(Map.merge(default_attrs, attrs))
    |> Repo.insert!()
  end

  describe "create_task/1" do
    test "inserts task with valid attrs" do
      user = user_fixture()

      assert {:ok, %TaskSchema{} = task} =
               TaskRepository.create_task(%{
                 instruction: "Write tests for login",
                 user_id: user.id
               })

      assert task.instruction == "Write tests for login"
      assert task.user_id == user.id
      assert task.status == "pending"
      assert task.id != nil
    end

    test "returns error changeset for invalid attrs" do
      assert {:error, %Ecto.Changeset{}} = TaskRepository.create_task(%{})
    end
  end

  describe "get_task/1" do
    test "returns task by id" do
      user = user_fixture()
      task = create_task(user)

      found = TaskRepository.get_task(task.id)
      assert found.id == task.id
      assert found.instruction == task.instruction
    end

    test "returns nil for non-existent id" do
      assert nil == TaskRepository.get_task(Ecto.UUID.generate())
    end
  end

  describe "get_task_for_user/2" do
    test "returns task owned by user" do
      user = user_fixture()
      task = create_task(user)

      found = TaskRepository.get_task_for_user(task.id, user.id)
      assert found.id == task.id
    end

    test "returns nil when task belongs to another user" do
      user = user_fixture()
      other_user = user_fixture()
      task = create_task(other_user)

      assert nil == TaskRepository.get_task_for_user(task.id, user.id)
    end

    test "returns nil for non-existent task" do
      user = user_fixture()
      assert nil == TaskRepository.get_task_for_user(Ecto.UUID.generate(), user.id)
    end
  end

  describe "update_task_status/2" do
    test "updates status and related fields" do
      user = user_fixture()
      task = create_task(user)

      assert {:ok, updated} =
               TaskRepository.update_task_status(task, %{
                 status: "starting",
                 container_id: "abc123",
                 container_port: 4096
               })

      assert updated.status == "starting"
      assert updated.container_id == "abc123"
      assert updated.container_port == 4096
    end

    test "returns error for invalid status" do
      user = user_fixture()
      task = create_task(user)

      assert {:error, %Ecto.Changeset{}} =
               TaskRepository.update_task_status(task, %{status: "bogus"})
    end
  end

  describe "list_tasks_for_user/2" do
    test "returns tasks ordered by most recent first" do
      user = user_fixture()
      task1 = create_task(user, %{instruction: "First"})
      Process.sleep(10)
      task2 = create_task(user, %{instruction: "Second"})

      tasks = TaskRepository.list_tasks_for_user(user.id)

      assert [first, second] = tasks
      assert first.id == task2.id
      assert second.id == task1.id
    end

    test "returns empty list when user has no tasks" do
      user = user_fixture()
      assert [] == TaskRepository.list_tasks_for_user(user.id)
    end

    test "only returns tasks for the specified user" do
      user = user_fixture()
      other_user = user_fixture()
      create_task(user, %{instruction: "My task"})
      create_task(other_user, %{instruction: "Their task"})

      tasks = TaskRepository.list_tasks_for_user(user.id)
      assert length(tasks) == 1
      assert hd(tasks).instruction == "My task"
    end
  end

  describe "running_task_count_for_user/1" do
    test "returns count of active tasks" do
      user = user_fixture()
      create_task(user, %{instruction: "Pending", status: "pending"})
      create_task(user, %{instruction: "Running", status: "running"})
      create_task(user, %{instruction: "Done", status: "completed"})

      assert 2 == TaskRepository.running_task_count_for_user(user.id)
    end

    test "returns 0 when no active tasks" do
      user = user_fixture()
      create_task(user, %{instruction: "Done", status: "completed"})

      assert 0 == TaskRepository.running_task_count_for_user(user.id)
    end
  end
end
