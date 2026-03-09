defmodule Agents.Sessions.Domain.Entities.SessionTest do
  use ExUnit.Case, async: true

  alias Agents.Sessions.Domain.Entities.Session

  describe "Session.new/1" do
    test "creates a session entity with provided fields" do
      queued_at = ~U[2026-03-09 10:00:00Z]

      session =
        Session.new(%{
          task_id: "task-123",
          user_id: "user-123",
          status: "queued",
          lifecycle_state: :queued_cold,
          container_id: nil,
          container_port: nil,
          session_id: "sess-123",
          instruction: "Run tests",
          error: nil,
          queue_position: 2,
          queued_at: queued_at
        })

      assert %Session{} = session
      assert session.task_id == "task-123"
      assert session.user_id == "user-123"
      assert session.status == "queued"
      assert session.lifecycle_state == :queued_cold
      assert session.container_id == nil
      assert session.container_port == nil
      assert session.session_id == "sess-123"
      assert session.instruction == "Run tests"
      assert session.error == nil
      assert session.queue_position == 2
      assert session.queued_at == queued_at
    end

    test "defaults lifecycle_state to idle" do
      session = Session.new(%{task_id: "task-123", user_id: "user-123"})

      assert session.lifecycle_state == :idle
    end
  end

  describe "Session.from_task/1" do
    test "converts task-like map into a session with derived lifecycle_state" do
      task = %{
        id: "task-123",
        user_id: "user-123",
        status: "queued",
        container_id: nil,
        container_port: nil,
        session_id: "sess-123",
        instruction: "Run tests",
        error: nil,
        queue_position: 1,
        queued_at: ~U[2026-03-09 10:00:00Z],
        started_at: nil,
        completed_at: nil
      }

      session = Session.from_task(task)

      assert session.task_id == "task-123"
      assert session.user_id == "user-123"
      assert session.status == "queued"
      assert session.lifecycle_state == :queued_cold
      assert session.container_id == nil
      assert session.container_port == nil
      assert session.session_id == "sess-123"
      assert session.instruction == "Run tests"
      assert session.error == nil
      assert session.queue_position == 1
      assert session.queued_at == ~U[2026-03-09 10:00:00Z]
      assert session.started_at == nil
      assert session.completed_at == nil
    end
  end

  describe "Session.from_task/2" do
    test "converts task-like map with runtime container metadata" do
      task = %{
        id: "task-123",
        user_id: "user-123",
        status: "pending",
        container_id: nil,
        container_port: nil,
        instruction: "Run tests"
      }

      metadata = %{container_id: "container-123", container_port: 4100}

      session = Session.from_task(task, metadata)

      assert session.task_id == "task-123"
      assert session.status == "pending"
      assert session.container_id == "container-123"
      assert session.container_port == 4100
      assert session.lifecycle_state == :pending
    end
  end

  describe "Session.valid_lifecycle_states/0" do
    test "returns the exact 11 lifecycle states" do
      assert Session.valid_lifecycle_states() == [
               :idle,
               :queued_cold,
               :queued_warm,
               :warming,
               :pending,
               :starting,
               :running,
               :awaiting_feedback,
               :completed,
               :failed,
               :cancelled
             ]
    end
  end

  describe "Session.display_name/1" do
    test "returns human-readable labels for all lifecycle states" do
      assert Session.display_name(:queued_cold) == "Queued (cold)"
      assert Session.display_name(:queued_warm) == "Queued (warm)"
      assert Session.display_name(:warming) == "Warming up"
      assert Session.display_name(:starting) == "Starting"
      assert Session.display_name(:running) == "Running"
      assert Session.display_name(:awaiting_feedback) == "Awaiting feedback"
      assert Session.display_name(:completed) == "Completed"
      assert Session.display_name(:failed) == "Failed"
      assert Session.display_name(:cancelled) == "Cancelled"
      assert Session.display_name(:idle) == "Idle"
      assert Session.display_name(:pending) == "Pending"
    end
  end
end
