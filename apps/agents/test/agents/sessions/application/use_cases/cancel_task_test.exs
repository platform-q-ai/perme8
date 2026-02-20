defmodule Agents.Sessions.Application.UseCases.CancelTaskTest do
  use Agents.DataCase, async: true

  import Mox

  alias Agents.Sessions.Application.UseCases.CancelTask
  alias Agents.Sessions.Infrastructure.Schemas.TaskSchema

  setup :verify_on_exit!

  describe "execute/3" do
    test "sends cancel to TaskRunner for a running task" do
      task = struct(TaskSchema, %{id: "task-1", user_id: "user-1", status: "running"})
      test_pid = self()

      Agents.Mocks.TaskRepositoryMock
      |> expect(:get_task_for_user, fn "task-1", "user-1" -> task end)

      cancel_fn = fn task_id ->
        send(test_pid, {:cancel_called, task_id})
        :ok
      end

      assert :ok =
               CancelTask.execute("task-1", "user-1",
                 task_repo: Agents.Mocks.TaskRepositoryMock,
                 task_runner_cancel: cancel_fn
               )

      assert_receive {:cancel_called, "task-1"}
    end

    test "returns error when task not found" do
      Agents.Mocks.TaskRepositoryMock
      |> expect(:get_task_for_user, fn "task-1", "user-1" -> nil end)

      assert {:error, :not_found} =
               CancelTask.execute("task-1", "user-1", task_repo: Agents.Mocks.TaskRepositoryMock)
    end

    test "returns error when task is not cancellable" do
      task = struct(TaskSchema, %{id: "task-1", user_id: "user-1", status: "completed"})

      Agents.Mocks.TaskRepositoryMock
      |> expect(:get_task_for_user, fn "task-1", "user-1" -> task end)

      assert {:error, :not_cancellable} =
               CancelTask.execute("task-1", "user-1", task_repo: Agents.Mocks.TaskRepositoryMock)
    end
  end
end
