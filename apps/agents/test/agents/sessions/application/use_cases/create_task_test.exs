defmodule Agents.Sessions.Application.UseCases.CreateTaskTest do
  use Agents.DataCase, async: true

  import Mox

  alias Agents.Mocks.TaskRepositoryMock
  alias Agents.Sessions.Application.UseCases.CreateTask
  alias Agents.Sessions.Domain.Events.TaskQueued
  alias Agents.Sessions.Infrastructure.Schemas.TaskSchema
  alias Perme8.Events.TestEventBus

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
        status: "queued",
        queue_position: 1
      }

      TaskRepositoryMock
      |> expect(:get_max_queue_position, fn "user-123" -> nil end)
      |> expect(:create_task, fn attrs ->
        assert attrs.instruction == "Write tests for the login flow"
        assert attrs.user_id == "user-123"
        assert attrs.status == "queued"
        {:ok, struct(TaskSchema, task_schema)}
      end)

      assert {:ok, task} =
               CreateTask.execute(@valid_attrs,
                 task_repo: TaskRepositoryMock
               )

      assert task.id == "task-1"
    end

    test "returns error when instruction is blank" do
      assert {:error, :instruction_required} =
               CreateTask.execute(%{instruction: "", user_id: "user-123"},
                 task_repo: TaskRepositoryMock
               )
    end

    test "returns error when instruction is nil" do
      assert {:error, :instruction_required} =
               CreateTask.execute(%{user_id: "user-123"},
                 task_repo: TaskRepositoryMock
               )
    end

    test "wraps queue decision and creation in concurrency lock callback" do
      task_schema = %{
        id: "task-1",
        instruction: "Write tests",
        user_id: "user-123",
        status: "queued",
        queue_position: 1
      }

      test_pid = self()

      TaskRepositoryMock
      |> expect(:get_max_queue_position, fn "user-123" -> nil end)
      |> expect(:create_task, fn _attrs ->
        send(test_pid, :created)
        {:ok, struct(TaskSchema, task_schema)}
      end)

      lock = fn user_id, fun ->
        send(test_pid, {:lock_entered, user_id})
        result = fun.()
        send(test_pid, :lock_exited)
        result
      end

      assert {:ok, _task} =
               CreateTask.execute(@valid_attrs,
                 task_repo: TaskRepositoryMock,
                 concurrency_lock: lock
               )

      assert_receive {:lock_entered, "user-123"}
      assert_receive :created
      assert_receive :lock_exited
    end

    test "returns domain entity" do
      task_schema = %{
        id: "task-1",
        instruction: "Write tests",
        user_id: "user-123",
        status: "queued",
        queue_position: 1,
        container_id: nil,
        container_port: nil,
        session_id: nil,
        error: nil,
        started_at: nil,
        completed_at: nil,
        inserted_at: ~U[2026-01-01 00:00:00.000000Z],
        updated_at: ~U[2026-01-01 00:00:00.000000Z]
      }

      TaskRepositoryMock
      |> expect(:get_max_queue_position, fn "user-123" -> nil end)
      |> expect(:create_task, fn _attrs ->
        {:ok, struct(TaskSchema, task_schema)}
      end)

      assert {:ok, task} =
               CreateTask.execute(@valid_attrs,
                 task_repo: TaskRepositoryMock
               )

      assert %Agents.Sessions.Domain.Entities.Task{} = task
    end

    test "emits TaskQueued domain event on success" do
      TestEventBus.start_global()

      task_schema = %{
        id: "task-1",
        instruction: "Write tests for the login flow",
        user_id: "user-123",
        status: "queued",
        queue_position: 1
      }

      TaskRepositoryMock
      |> expect(:get_max_queue_position, fn "user-123" -> nil end)
      |> expect(:create_task, fn _attrs ->
        {:ok, struct(TaskSchema, task_schema)}
      end)

      assert {:ok, _task} =
               CreateTask.execute(@valid_attrs,
                 task_repo: TaskRepositoryMock,
                 event_bus: TestEventBus
               )

      events = TestEventBus.get_events()
      assert [%TaskQueued{} = event] = events
      assert event.task_id == "task-1"
      assert event.user_id == "user-123"
      assert event.aggregate_id == "task-1"
      assert event.actor_id == "user-123"
      assert event.queue_position == 1
    end

    test "does not emit event on validation failure" do
      TestEventBus.start_global()

      assert {:error, :instruction_required} =
               CreateTask.execute(%{instruction: "", user_id: "user-123"},
                 task_repo: TaskRepositoryMock,
                 event_bus: TestEventBus
               )

      assert TestEventBus.get_events() == []
    end
  end
end
