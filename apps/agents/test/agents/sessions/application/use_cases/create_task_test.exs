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
    test "creates task when instruction is valid" do
      task_schema = %{
        id: "task-1",
        instruction: "Write tests",
        user_id: "user-123",
        status: "pending"
      }

      Agents.Mocks.TaskRepositoryMock
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

    test "starts TaskRunner after successful creation" do
      task_schema = %{
        id: "task-1",
        instruction: "Write tests",
        user_id: "user-123",
        status: "pending"
      }

      test_pid = self()

      Agents.Mocks.TaskRepositoryMock
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

    test "returns error when runner start fails" do
      task_schema = %{
        id: "task-1",
        instruction: "Write tests",
        user_id: "user-123",
        status: "pending"
      }

      schema = struct(Agents.Sessions.Infrastructure.Schemas.TaskSchema, task_schema)

      Agents.Mocks.TaskRepositoryMock
      |> expect(:create_task, fn _attrs -> {:ok, schema} end)
      |> expect(:get_task, fn "task-1" -> schema end)
      |> expect(:update_task_status, fn _task, %{status: "failed"} -> {:ok, schema} end)

      assert {:error, :runner_start_failed} =
               CreateTask.execute(@valid_attrs,
                 task_repo: Agents.Mocks.TaskRepositoryMock,
                 task_runner_starter: fn _task_id, _opts -> {:error, :already_started} end
               )
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

    test "emits TaskCreated domain event on success" do
      Perme8.Events.TestEventBus.start_global()

      task_schema = %{
        id: "task-1",
        instruction: "Write tests for the login flow",
        user_id: "user-123",
        status: "pending"
      }

      Agents.Mocks.TaskRepositoryMock
      |> expect(:create_task, fn _attrs ->
        {:ok, struct(Agents.Sessions.Infrastructure.Schemas.TaskSchema, task_schema)}
      end)

      assert {:ok, _task} =
               CreateTask.execute(@valid_attrs,
                 task_repo: Agents.Mocks.TaskRepositoryMock,
                 task_runner_starter: fn _id, _opts -> {:ok, self()} end,
                 event_bus: Perme8.Events.TestEventBus
               )

      events = Perme8.Events.TestEventBus.get_events()
      assert [%Agents.Sessions.Domain.Events.TaskCreated{} = event] = events
      assert event.task_id == "task-1"
      assert event.user_id == "user-123"
      assert event.instruction == "Write tests for the login flow"
      assert event.aggregate_id == "task-1"
      assert event.actor_id == "user-123"
    end

    test "does not emit event on validation failure" do
      Perme8.Events.TestEventBus.start_global()

      assert {:error, :instruction_required} =
               CreateTask.execute(%{instruction: "", user_id: "user-123"},
                 task_repo: Agents.Mocks.TaskRepositoryMock,
                 event_bus: Perme8.Events.TestEventBus
               )

      assert Perme8.Events.TestEventBus.get_events() == []
    end
  end
end
