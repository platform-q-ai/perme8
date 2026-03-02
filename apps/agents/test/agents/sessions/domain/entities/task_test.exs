defmodule Agents.Sessions.Domain.Entities.TaskTest do
  use ExUnit.Case, async: true

  alias Agents.Sessions.Domain.Entities.Task

  describe "Task.new/1" do
    test "creates a new task entity with required fields" do
      attrs = %{
        user_id: "user-123",
        instruction: "Write tests for the login flow"
      }

      task = Task.new(attrs)

      assert %Task{} = task
      assert task.user_id == "user-123"
      assert task.instruction == "Write tests for the login flow"
    end

    test "sets default status to pending" do
      attrs = %{
        user_id: "user-123",
        instruction: "Fix the bug"
      }

      task = Task.new(attrs)

      assert task.status == "pending"
    end

    test "allows overriding default values" do
      attrs = %{
        user_id: "user-123",
        instruction: "Run tests",
        status: "running"
      }

      task = Task.new(attrs)

      assert task.status == "running"
    end

    test "includes all fields in struct" do
      task = Task.new(%{user_id: "user-123", instruction: "Test"})

      assert Map.has_key?(task, :id)
      assert Map.has_key?(task, :instruction)
      assert Map.has_key?(task, :status)
      assert Map.has_key?(task, :container_id)
      assert Map.has_key?(task, :container_port)
      assert Map.has_key?(task, :session_id)
      assert Map.has_key?(task, :user_id)
      assert Map.has_key?(task, :error)
      assert Map.has_key?(task, :output)
      assert Map.has_key?(task, :todo_items)
      assert Map.has_key?(task, :parent_task_id)
      assert Map.has_key?(task, :queue_position)
      assert Map.has_key?(task, :queued_at)
      assert Map.has_key?(task, :started_at)
      assert Map.has_key?(task, :completed_at)
      assert Map.has_key?(task, :inserted_at)
      assert Map.has_key?(task, :updated_at)
    end

    test "accepts todo_items and defaults to nil when omitted" do
      with_todos =
        Task.new(%{
          user_id: "user-123",
          instruction: "Test",
          todo_items: %{"items" => [%{"id" => "todo-1"}]}
        })

      without_todos = Task.new(%{user_id: "user-123", instruction: "Test"})

      assert with_todos.todo_items == %{"items" => [%{"id" => "todo-1"}]}
      assert without_todos.todo_items == nil
    end
  end

  describe "Task.from_schema/1" do
    test "converts a schema to a domain entity" do
      schema = %{
        __struct__: SomeSchema,
        id: "task-123",
        instruction: "Write tests for the login flow",
        status: "running",
        image: "perme8-opencode",
        container_id: "abc123",
        container_port: 4096,
        session_id: "sess-456",
        user_id: "user-789",
        error: nil,
        output: nil,
        todo_items: %{
          "items" => [
            %{"id" => "todo-1", "title" => "Plan", "status" => "pending", "position" => 0}
          ]
        },
        parent_task_id: nil,
        pending_question: nil,
        queue_position: 2,
        queued_at: ~U[2026-01-01 00:00:00.000000Z],
        started_at: ~U[2026-01-01 00:00:00.000000Z],
        completed_at: nil,
        inserted_at: ~U[2026-01-01 00:00:00.000000Z],
        updated_at: ~U[2026-01-02 00:00:00.000000Z]
      }

      task = Task.from_schema(schema)

      assert %Task{} = task
      assert task.id == "task-123"
      assert task.instruction == "Write tests for the login flow"
      assert task.status == "running"
      assert task.image == "perme8-opencode"
      assert task.container_id == "abc123"
      assert task.container_port == 4096
      assert task.session_id == "sess-456"
      assert task.user_id == "user-789"
      assert task.error == nil
      assert task.output == nil

      assert task.todo_items == %{
               "items" => [
                 %{"id" => "todo-1", "title" => "Plan", "status" => "pending", "position" => 0}
               ]
             }

      assert task.parent_task_id == nil
      assert task.queue_position == 2
      assert task.queued_at == ~U[2026-01-01 00:00:00.000000Z]
      assert task.started_at == ~U[2026-01-01 00:00:00.000000Z]
      assert task.completed_at == nil
      assert task.inserted_at == ~U[2026-01-01 00:00:00.000000Z]
      assert task.updated_at == ~U[2026-01-02 00:00:00.000000Z]
    end

    test "handles nil optional fields" do
      schema = %{
        __struct__: SomeSchema,
        id: "task-123",
        instruction: "Do something",
        status: "pending",
        image: "perme8-opencode",
        container_id: nil,
        container_port: nil,
        session_id: nil,
        user_id: "user-123",
        error: nil,
        output: nil,
        todo_items: nil,
        parent_task_id: nil,
        pending_question: nil,
        queue_position: nil,
        queued_at: nil,
        started_at: nil,
        completed_at: nil,
        inserted_at: ~U[2026-01-01 00:00:00.000000Z],
        updated_at: ~U[2026-01-01 00:00:00.000000Z]
      }

      task = Task.from_schema(schema)

      assert %Task{} = task
      assert task.container_id == nil
      assert task.container_port == nil
      assert task.session_id == nil
      assert task.error == nil
      assert task.todo_items == nil
      assert task.queue_position == nil
      assert task.queued_at == nil
    end
  end

  describe "Task.valid_statuses/0" do
    test "returns list of valid status values" do
      statuses = Task.valid_statuses()

      assert is_list(statuses)
      assert "pending" in statuses
      assert "starting" in statuses
      assert "running" in statuses
      assert "completed" in statuses
      assert "failed" in statuses
      assert "cancelled" in statuses
      assert "queued" in statuses
      assert "awaiting_feedback" in statuses
    end

    test "returns exactly 8 statuses" do
      assert length(Task.valid_statuses()) == 8
    end
  end

  describe "queue fields" do
    test "queue_position defaults to nil" do
      task = Task.new(%{user_id: "user-123", instruction: "Test"})
      assert task.queue_position == nil
    end

    test "queued_at defaults to nil" do
      task = Task.new(%{user_id: "user-123", instruction: "Test"})
      assert task.queued_at == nil
    end

    test "accepts queue_position and queued_at" do
      now = DateTime.utc_now()

      task =
        Task.new(%{
          user_id: "user-123",
          instruction: "Test",
          queue_position: 3,
          queued_at: now
        })

      assert task.queue_position == 3
      assert task.queued_at == now
    end
  end
end
