defmodule Agents.Sessions.Application.UseCases.DeleteSessionTest do
  use Agents.DataCase, async: true

  import Mox

  alias Agents.Sessions.Application.UseCases.DeleteSession
  alias Agents.Sessions.Infrastructure.Schemas.TaskSchema

  setup :verify_on_exit!

  defp default_opts do
    [
      task_repo: Agents.Mocks.TaskRepositoryMock,
      container_provider: Agents.Mocks.ContainerProviderMock,
      task_runner_cancel: fn _task_id -> :ok end
    ]
  end

  describe "execute/3" do
    test "deletes container and all tasks for a session" do
      tasks = [
        struct(TaskSchema, %{id: "t1", user_id: "user-1", status: "completed", container_id: "c1"}),
        struct(TaskSchema, %{id: "t2", user_id: "user-1", status: "failed", container_id: "c1"})
      ]

      Agents.Mocks.TaskRepositoryMock
      |> expect(:list_tasks_for_container, fn "c1", "user-1" -> tasks end)
      |> expect(:delete_tasks_for_container, fn "c1", "user-1" -> {2, nil} end)

      Agents.Mocks.ContainerProviderMock
      |> expect(:remove, fn "c1" -> :ok end)

      assert :ok = DeleteSession.execute("c1", "user-1", default_opts())
    end

    test "calls remove (not stop) on the container" do
      tasks = [
        struct(TaskSchema, %{id: "t1", user_id: "user-1", status: "completed", container_id: "c1"})
      ]

      Agents.Mocks.TaskRepositoryMock
      |> expect(:list_tasks_for_container, fn "c1", "user-1" -> tasks end)
      |> expect(:delete_tasks_for_container, fn "c1", "user-1" -> {1, nil} end)

      # Intentionally no stop expectation: DeleteSession must only remove.
      Agents.Mocks.ContainerProviderMock
      |> expect(:remove, fn "c1" -> :ok end)

      assert :ok = DeleteSession.execute("c1", "user-1", default_opts())
    end

    test "returns :not_found when no tasks exist for container" do
      Agents.Mocks.TaskRepositoryMock
      |> expect(:list_tasks_for_container, fn "c1", "user-1" -> [] end)

      assert {:error, :not_found} = DeleteSession.execute("c1", "user-1", default_opts())
    end

    test "cancels running task runners before deletion" do
      test_pid = self()

      tasks = [
        struct(TaskSchema, %{id: "t1", user_id: "user-1", status: "running", container_id: "c1"}),
        struct(TaskSchema, %{id: "t2", user_id: "user-1", status: "pending", container_id: "c1"}),
        struct(TaskSchema, %{id: "t3", user_id: "user-1", status: "completed", container_id: "c1"})
      ]

      cancel_fn = fn task_id ->
        send(test_pid, {:cancelled, task_id})
        :ok
      end

      Agents.Mocks.TaskRepositoryMock
      |> expect(:list_tasks_for_container, fn "c1", "user-1" -> tasks end)
      |> expect(:delete_tasks_for_container, fn "c1", "user-1" -> {3, nil} end)

      Agents.Mocks.ContainerProviderMock
      |> expect(:remove, fn "c1" -> :ok end)

      opts = Keyword.put(default_opts(), :task_runner_cancel, cancel_fn)

      assert :ok = DeleteSession.execute("c1", "user-1", opts)

      # Running and pending tasks should be cancelled
      assert_receive {:cancelled, "t1"}
      assert_receive {:cancelled, "t2"}
      # Completed task should NOT be cancelled
      refute_receive {:cancelled, "t3"}
    end

    test "returns error and preserves DB records when container removal fails" do
      tasks = [
        struct(TaskSchema, %{id: "t1", user_id: "user-1", status: "completed", container_id: "c1"})
      ]

      Agents.Mocks.TaskRepositoryMock
      |> expect(:list_tasks_for_container, fn "c1", "user-1" -> tasks end)

      # No delete_tasks_for_container expectation — it must NOT be called

      Agents.Mocks.ContainerProviderMock
      |> expect(:remove, fn "c1" -> {:error, "container not found"} end)

      assert {:error, {:container_remove_failed, "container not found"}} =
               DeleteSession.execute("c1", "user-1", default_opts())
    end

    test "cancels starting tasks" do
      test_pid = self()

      tasks = [
        struct(TaskSchema, %{id: "t1", user_id: "user-1", status: "starting", container_id: "c1"})
      ]

      cancel_fn = fn task_id ->
        send(test_pid, {:cancelled, task_id})
        :ok
      end

      Agents.Mocks.TaskRepositoryMock
      |> expect(:list_tasks_for_container, fn "c1", "user-1" -> tasks end)
      |> expect(:delete_tasks_for_container, fn "c1", "user-1" -> {1, nil} end)

      Agents.Mocks.ContainerProviderMock
      |> expect(:remove, fn "c1" -> :ok end)

      opts = Keyword.put(default_opts(), :task_runner_cancel, cancel_fn)

      assert :ok = DeleteSession.execute("c1", "user-1", opts)
      assert_receive {:cancelled, "t1"}
    end

    test "cancels awaiting_feedback tasks" do
      test_pid = self()

      tasks = [
        struct(TaskSchema, %{
          id: "t1",
          user_id: "user-1",
          status: "awaiting_feedback",
          container_id: "c1"
        })
      ]

      cancel_fn = fn task_id ->
        send(test_pid, {:cancelled, task_id})
        :ok
      end

      Agents.Mocks.TaskRepositoryMock
      |> expect(:list_tasks_for_container, fn "c1", "user-1" -> tasks end)
      |> expect(:delete_tasks_for_container, fn "c1", "user-1" -> {1, nil} end)

      Agents.Mocks.ContainerProviderMock
      |> expect(:remove, fn "c1" -> :ok end)

      opts = Keyword.put(default_opts(), :task_runner_cancel, cancel_fn)

      assert :ok = DeleteSession.execute("c1", "user-1", opts)
      assert_receive {:cancelled, "t1"}
    end

    test "does not cancel completed, failed, or cancelled tasks" do
      test_pid = self()

      tasks = [
        struct(TaskSchema, %{
          id: "t1",
          user_id: "user-1",
          status: "completed",
          container_id: "c1"
        }),
        struct(TaskSchema, %{id: "t2", user_id: "user-1", status: "failed", container_id: "c1"}),
        struct(TaskSchema, %{
          id: "t3",
          user_id: "user-1",
          status: "cancelled",
          container_id: "c1"
        })
      ]

      cancel_fn = fn task_id ->
        send(test_pid, {:cancelled, task_id})
        :ok
      end

      Agents.Mocks.TaskRepositoryMock
      |> expect(:list_tasks_for_container, fn "c1", "user-1" -> tasks end)
      |> expect(:delete_tasks_for_container, fn "c1", "user-1" -> {3, nil} end)

      Agents.Mocks.ContainerProviderMock
      |> expect(:remove, fn "c1" -> :ok end)

      opts = Keyword.put(default_opts(), :task_runner_cancel, cancel_fn)

      assert :ok = DeleteSession.execute("c1", "user-1", opts)

      refute_receive {:cancelled, _}
    end
  end
end
