defmodule Agents.Sessions.Application.UseCases.ListTasksTest do
  use Agents.DataCase, async: true

  import Mox

  alias Agents.Sessions.Application.UseCases.ListTasks
  alias Agents.Sessions.Domain.Entities.Task
  alias Agents.Sessions.Infrastructure.Schemas.TaskSchema

  setup :verify_on_exit!

  describe "execute/2" do
    test "returns list of domain entities for user" do
      schemas = [
        struct(TaskSchema, %{
          id: "task-2",
          instruction: "Second task",
          user_id: "user-1",
          status: "completed",
          container_id: nil,
          container_port: nil,
          session_id: nil,
          error: nil,
          started_at: nil,
          completed_at: nil,
          inserted_at: ~U[2026-01-02 00:00:00.000000Z],
          updated_at: ~U[2026-01-02 00:00:00.000000Z]
        }),
        struct(TaskSchema, %{
          id: "task-1",
          instruction: "First task",
          user_id: "user-1",
          status: "pending",
          container_id: nil,
          container_port: nil,
          session_id: nil,
          error: nil,
          started_at: nil,
          completed_at: nil,
          inserted_at: ~U[2026-01-01 00:00:00.000000Z],
          updated_at: ~U[2026-01-01 00:00:00.000000Z]
        })
      ]

      Agents.Mocks.TaskRepositoryMock
      |> expect(:list_tasks_for_user, fn "user-1", _opts -> schemas end)

      tasks =
        ListTasks.execute("user-1",
          task_repo: Agents.Mocks.TaskRepositoryMock
        )

      assert length(tasks) == 2
      assert [%Task{id: "task-2"}, %Task{id: "task-1"}] = tasks
    end

    test "returns empty list when user has no tasks" do
      Agents.Mocks.TaskRepositoryMock
      |> expect(:list_tasks_for_user, fn "user-1", _opts -> [] end)

      tasks =
        ListTasks.execute("user-1",
          task_repo: Agents.Mocks.TaskRepositoryMock
        )

      assert tasks == []
    end
  end
end
