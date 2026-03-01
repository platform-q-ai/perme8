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
               Sessions.create_task(
                 %{instruction: "Write tests", user_id: user.id},
                 task_runner_starter: fn _id, _opts -> {:ok, self()} end
               )

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

  describe "delete_task/2" do
    test "deletes a completed task" do
      user = user_fixture()
      task = task_fixture(%{user_id: user.id, status: "completed"})

      assert :ok = Sessions.delete_task(task.id, user.id)
      assert {:error, :not_found} = Sessions.get_task(task.id, user.id)
    end

    test "deletes a failed task" do
      user = user_fixture()
      task = task_fixture(%{user_id: user.id, status: "failed"})

      assert :ok = Sessions.delete_task(task.id, user.id)
      assert {:error, :not_found} = Sessions.get_task(task.id, user.id)
    end

    test "returns error for running task" do
      user = user_fixture()
      task = task_fixture(%{user_id: user.id, status: "running"})

      assert {:error, :not_deletable} = Sessions.delete_task(task.id, user.id)
    end

    test "returns error for non-existent task" do
      user = user_fixture()
      assert {:error, :not_found} = Sessions.delete_task(Ecto.UUID.generate(), user.id)
    end

    test "returns error for other user's task" do
      user = user_fixture()
      other_user = user_fixture()
      task = task_fixture(%{user_id: other_user.id, status: "completed"})

      assert {:error, :not_found} = Sessions.delete_task(task.id, user.id)
    end
  end

  describe "list_sessions/2" do
    test "returns sessions grouped by container_id" do
      user = user_fixture()
      container_a = "container-aaa"
      container_b = "container-bbb"

      task_fixture(%{
        user_id: user.id,
        instruction: "First task in A",
        container_id: container_a,
        status: "completed"
      })

      task_fixture(%{
        user_id: user.id,
        instruction: "Second task in A",
        container_id: container_a,
        status: "completed"
      })

      task_fixture(%{
        user_id: user.id,
        instruction: "Only task in B",
        container_id: container_b,
        status: "completed"
      })

      sessions = Sessions.list_sessions(user.id)

      assert length(sessions) == 2

      session_a = Enum.find(sessions, &(&1.container_id == container_a))
      session_b = Enum.find(sessions, &(&1.container_id == container_b))

      assert session_a.task_count == 2
      assert session_a.title == "First task in A"

      assert session_b.task_count == 1
      assert session_b.title == "Only task in B"
      assert session_b.latest_status == "completed"
    end

    test "returns empty list for user with no sessions" do
      user = user_fixture()
      assert [] == Sessions.list_sessions(user.id)
    end

    test "excludes tasks without container_id" do
      user = user_fixture()

      # Task with no container_id — should not appear in sessions
      task_fixture(%{user_id: user.id, instruction: "No container"})

      # Task with a container_id — should appear
      task_fixture(%{
        user_id: user.id,
        instruction: "With container",
        container_id: "container-xyz"
      })

      sessions = Sessions.list_sessions(user.id)

      assert length(sessions) == 1
      assert hd(sessions).container_id == "container-xyz"
    end
  end

  describe "get_container_stats/2" do
    test "delegates to container provider" do
      {:module, mock_mod, _, _} =
        defmodule :"Agents.SessionsTest.MockContainerStats.#{System.unique_integer([:positive])}" do
          def stats("container-123") do
            {:ok, %{cpu_percent: 25.0, memory_usage: 100, memory_limit: 200}}
          end
        end

      assert {:ok, stats} =
               Sessions.get_container_stats("container-123", container_provider: mock_mod)

      assert stats.cpu_percent == 25.0
      assert stats.memory_usage == 100
      assert stats.memory_limit == 200
    end

    test "returns error for unknown container" do
      {:module, mock_mod, _, _} =
        defmodule :"Agents.SessionsTest.MockContainerStatsError.#{System.unique_integer([:positive])}" do
          def stats(_container_id) do
            {:error, :not_found}
          end
        end

      assert {:error, :not_found} =
               Sessions.get_container_stats("unknown-container", container_provider: mock_mod)
    end
  end

  describe "answer_question/3" do
    test "returns :task_not_running when no runner registered" do
      task_id = Ecto.UUID.generate()
      request_id = "req-123"
      answers = [["Option A"]]

      assert {:error, :task_not_running} =
               Sessions.answer_question(task_id, request_id, answers)
    end
  end

  describe "reject_question/2" do
    test "returns :task_not_running when no runner registered" do
      task_id = Ecto.UUID.generate()
      request_id = "req-456"

      assert {:error, :task_not_running} =
               Sessions.reject_question(task_id, request_id)
    end
  end

  describe "send_message/2" do
    test "returns :task_not_running when no runner registered" do
      task_id = Ecto.UUID.generate()

      assert {:error, :task_not_running} =
               Sessions.send_message(task_id, "hello")
    end
  end

  describe "delete_session/3" do
    test "deletes all tasks for a container" do
      user = user_fixture()
      container_id = "container-to-delete"

      {:module, mock_mod, _, _} =
        defmodule :"Agents.SessionsTest.MockContainerRemove.#{System.unique_integer([:positive])}" do
          def remove(_container_id), do: :ok
        end

      task_fixture(%{
        user_id: user.id,
        instruction: "Task 1",
        container_id: container_id,
        status: "completed"
      })

      task_fixture(%{
        user_id: user.id,
        instruction: "Task 2",
        container_id: container_id,
        status: "completed"
      })

      assert :ok =
               Sessions.delete_session(container_id, user.id,
                 container_provider: mock_mod,
                 task_runner_cancel: fn _id -> :ok end
               )

      # All tasks for this container should be gone
      assert Sessions.list_sessions(user.id) == []
    end

    test "returns error for non-existent container" do
      user = user_fixture()

      assert {:error, :not_found} =
               Sessions.delete_session("non-existent-container", user.id)
    end
  end

  describe "resume_task/3" do
    test "updates the existing task with new instruction and resets status" do
      user = user_fixture()
      container_id = "container-resume"
      session_id = "session-resume"

      task =
        task_fixture(%{
          user_id: user.id,
          instruction: "Original task",
          container_id: container_id,
          session_id: session_id,
          status: "completed"
        })

      assert {:ok, %Task{} = resumed} =
               Sessions.resume_task(
                 task.id,
                 %{instruction: "Follow-up task", user_id: user.id},
                 task_runner_starter: fn _id, _opts -> {:ok, self()} end
               )

      # Same task record, updated in place
      assert resumed.id == task.id
      assert resumed.instruction == "Follow-up task"
      assert resumed.status == "pending"
      assert resumed.container_id == container_id
      assert resumed.session_id == session_id
      assert resumed.user_id == user.id
    end

    test "returns error for non-existent task" do
      user = user_fixture()

      assert {:error, :not_found} =
               Sessions.resume_task(
                 Ecto.UUID.generate(),
                 %{instruction: "Follow-up", user_id: user.id},
                 task_runner_starter: fn _id, _opts -> {:ok, self()} end
               )
    end

    test "returns error for active task" do
      user = user_fixture()

      task =
        task_fixture(%{
          user_id: user.id,
          instruction: "Still running",
          container_id: "container-active",
          session_id: "session-active",
          status: "running"
        })

      assert {:error, :already_active} =
               Sessions.resume_task(
                 task.id,
                 %{instruction: "Follow-up", user_id: user.id},
                 task_runner_starter: fn _id, _opts -> {:ok, self()} end
               )
    end

    test "returns error for task without container" do
      user = user_fixture()

      task =
        task_fixture(%{
          user_id: user.id,
          instruction: "No container task",
          status: "completed"
        })

      assert {:error, :no_container} =
               Sessions.resume_task(
                 task.id,
                 %{instruction: "Follow-up", user_id: user.id},
                 task_runner_starter: fn _id, _opts -> {:ok, self()} end
               )
    end
  end

  describe "refresh_auth_and_resume/3" do
    test "returns error for non-existent task" do
      user = user_fixture()

      assert {:error, :not_found} =
               Sessions.refresh_auth_and_resume(Ecto.UUID.generate(), user.id,
                 task_runner_starter: fn _id, _opts -> {:ok, self()} end,
                 resume_fn: fn _id, _attrs, _opts -> {:ok, %Task{}} end
               )
    end

    test "returns error for non-failed task" do
      user = user_fixture()

      task =
        task_fixture(%{
          user_id: user.id,
          instruction: "Completed task",
          container_id: "container-auth",
          status: "completed"
        })

      assert {:error, :not_resumable} =
               Sessions.refresh_auth_and_resume(task.id, user.id,
                 task_runner_starter: fn _id, _opts -> {:ok, self()} end,
                 resume_fn: fn _id, _attrs, _opts -> {:ok, %Task{}} end
               )
    end

    test "returns error for failed task without container" do
      user = user_fixture()

      task =
        task_fixture(%{
          user_id: user.id,
          instruction: "Failed without container",
          status: "failed"
        })

      assert {:error, :no_container} =
               Sessions.refresh_auth_and_resume(task.id, user.id,
                 task_runner_starter: fn _id, _opts -> {:ok, self()} end,
                 resume_fn: fn _id, _attrs, _opts -> {:ok, %Task{}} end
               )
    end
  end
end
