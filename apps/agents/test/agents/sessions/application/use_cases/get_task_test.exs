defmodule Agents.Sessions.Application.UseCases.GetTaskTest do
  use Agents.DataCase, async: true

  import Mox

  alias Agents.Sessions.Application.UseCases.GetTask
  alias Agents.Sessions.Domain.Entities.Task
  alias Agents.Sessions.Infrastructure.Schemas.TaskSchema

  setup :verify_on_exit!

  describe "execute/3" do
    test "returns domain entity when task exists and owned by user" do
      task_schema =
        struct(TaskSchema, %{
          id: "task-1",
          instruction: "Write tests",
          user_id: "user-1",
          status: "running",
          container_id: "abc",
          container_port: 4096,
          session_id: "sess-1",
          error: nil,
          started_at: ~U[2026-01-01 00:00:00.000000Z],
          completed_at: nil,
          inserted_at: ~U[2026-01-01 00:00:00.000000Z],
          updated_at: ~U[2026-01-01 00:00:00.000000Z]
        })

      Agents.Mocks.TaskRepositoryMock
      |> expect(:get_task_for_user, fn "task-1", "user-1" -> task_schema end)

      assert {:ok, %Task{} = task} =
               GetTask.execute("task-1", "user-1", task_repo: Agents.Mocks.TaskRepositoryMock)

      assert task.id == "task-1"
      assert task.instruction == "Write tests"
      assert task.status == "running"
    end

    test "returns error when task not found" do
      Agents.Mocks.TaskRepositoryMock
      |> expect(:get_task_for_user, fn "task-1", "user-1" -> nil end)

      assert {:error, :not_found} =
               GetTask.execute("task-1", "user-1", task_repo: Agents.Mocks.TaskRepositoryMock)
    end

    test "returns error when task belongs to another user" do
      Agents.Mocks.TaskRepositoryMock
      |> expect(:get_task_for_user, fn "task-1", "user-1" -> nil end)

      assert {:error, :not_found} =
               GetTask.execute("task-1", "user-1", task_repo: Agents.Mocks.TaskRepositoryMock)
    end
  end
end
