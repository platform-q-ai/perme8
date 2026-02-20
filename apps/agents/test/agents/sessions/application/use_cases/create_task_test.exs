defmodule Agents.Sessions.Application.UseCases.CreateTaskTest do
  use Agents.DataCase, async: true

  import Mox

  alias Agents.Sessions.Application.UseCases.CreateTask

  setup :verify_on_exit!

  @valid_attrs %{
    instruction: "Write tests for the login flow",
    user_id: "user-123"
  }

  describe "execute/2" do
    test "creates task when instruction is valid and no tasks running" do
      task_schema = %{
        id: "task-1",
        instruction: "Write tests",
        user_id: "user-123",
        status: "pending"
      }

      Agents.Mocks.TaskRepositoryMock
      |> expect(:running_task_count_for_user, fn "user-123" -> 0 end)
      |> expect(:create_task, fn attrs ->
        assert attrs.instruction == "Write tests for the login flow"
        assert attrs.user_id == "user-123"
        {:ok, struct(Agents.Sessions.Infrastructure.Schemas.TaskSchema, task_schema)}
      end)

      assert {:ok, task} =
               CreateTask.execute(@valid_attrs,
                 task_repo: Agents.Mocks.TaskRepositoryMock,
                 task_runner_starter: fn _task_id, _opts -> {:ok, self()} end
               )

      assert task.id == "task-1"
    end

    test "returns error when instruction is blank" do
      assert {:error, :instruction_required} =
               CreateTask.execute(%{instruction: "", user_id: "user-123"},
                 task_repo: Agents.Mocks.TaskRepositoryMock
               )
    end

    test "returns error when instruction is nil" do
      assert {:error, :instruction_required} =
               CreateTask.execute(%{user_id: "user-123"},
                 task_repo: Agents.Mocks.TaskRepositoryMock
               )
    end

    test "returns error when concurrent limit is reached" do
      Agents.Mocks.TaskRepositoryMock
      |> expect(:running_task_count_for_user, fn "user-123" -> 1 end)

      assert {:error, :concurrent_limit_reached} =
               CreateTask.execute(@valid_attrs,
                 task_repo: Agents.Mocks.TaskRepositoryMock
               )
    end

    test "starts TaskRunner after successful creation" do
      task_schema = %{
        id: "task-1",
        instruction: "Write tests",
        user_id: "user-123",
        status: "pending"
      }

      test_pid = self()

      Agents.Mocks.TaskRepositoryMock
      |> expect(:running_task_count_for_user, fn "user-123" -> 0 end)
      |> expect(:create_task, fn _attrs ->
        {:ok, struct(Agents.Sessions.Infrastructure.Schemas.TaskSchema, task_schema)}
      end)

      starter = fn task_id, _opts ->
        send(test_pid, {:started, task_id})
        {:ok, self()}
      end

      assert {:ok, _task} =
               CreateTask.execute(@valid_attrs,
                 task_repo: Agents.Mocks.TaskRepositoryMock,
                 task_runner_starter: starter
               )

      assert_receive {:started, "task-1"}
    end

    test "returns domain entity" do
      task_schema = %{
        id: "task-1",
        instruction: "Write tests",
        user_id: "user-123",
        status: "pending",
        container_id: nil,
        container_port: nil,
        session_id: nil,
        error: nil,
        started_at: nil,
        completed_at: nil,
        inserted_at: ~U[2026-01-01 00:00:00.000000Z],
        updated_at: ~U[2026-01-01 00:00:00.000000Z]
      }

      Agents.Mocks.TaskRepositoryMock
      |> expect(:running_task_count_for_user, fn "user-123" -> 0 end)
      |> expect(:create_task, fn _attrs ->
        {:ok, struct(Agents.Sessions.Infrastructure.Schemas.TaskSchema, task_schema)}
      end)

      assert {:ok, task} =
               CreateTask.execute(@valid_attrs,
                 task_repo: Agents.Mocks.TaskRepositoryMock,
                 task_runner_starter: fn _id, _opts -> {:ok, self()} end
               )

      assert %Agents.Sessions.Domain.Entities.Task{} = task
    end
  end
end
