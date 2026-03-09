defmodule AgentsWeb.SessionsLive.SessionStateMachineTest do
  use ExUnit.Case, async: true

  alias AgentsWeb.SessionsLive.SessionStateMachine

  describe "state_from_task/1" do
    test "returns :idle for nil task" do
      assert SessionStateMachine.state_from_task(nil) == :idle
    end

    test "returns :idle for nil status" do
      assert SessionStateMachine.state_from_task(%{status: nil}) == :idle
    end

    test "maps known status strings to atoms" do
      assert SessionStateMachine.state_from_task(%{status: "pending"}) == :pending
      assert SessionStateMachine.state_from_task(%{status: "starting"}) == :starting
      assert SessionStateMachine.state_from_task(%{status: "running"}) == :running
      assert SessionStateMachine.state_from_task(%{status: "queued"}) == :queued

      assert SessionStateMachine.state_from_task(%{status: "awaiting_feedback"}) ==
               :awaiting_feedback

      assert SessionStateMachine.state_from_task(%{status: "completed"}) == :completed
      assert SessionStateMachine.state_from_task(%{status: "failed"}) == :failed
      assert SessionStateMachine.state_from_task(%{status: "cancelled"}) == :cancelled
    end

    test "prefers lifecycle_state when present" do
      assert SessionStateMachine.state_from_task(%{
               status: "queued",
               lifecycle_state: "queued_cold"
             }) ==
               :queued_cold

      assert SessionStateMachine.state_from_task(%{
               status: "queued",
               lifecycle_state: "queued_warm"
             }) ==
               :queued_warm

      assert SessionStateMachine.state_from_task(%{status: "pending", lifecycle_state: "warming"}) ==
               :warming
    end

    test "falls back to status mapping when lifecycle_state is nil" do
      assert SessionStateMachine.state_from_task(%{status: "queued", lifecycle_state: nil}) ==
               :queued
    end

    test "returns :unknown for unrecognized status strings" do
      assert SessionStateMachine.state_from_task(%{status: "bogus"}) == :unknown
      assert SessionStateMachine.state_from_task(%{status: ""}) == :unknown
    end
  end

  describe "task_running?/1" do
    test "returns true for pending, warming, starting, running" do
      assert SessionStateMachine.task_running?(:pending)
      assert SessionStateMachine.task_running?(:warming)
      assert SessionStateMachine.task_running?(:starting)
      assert SessionStateMachine.task_running?(:running)
    end

    test "returns false for queued, awaiting_feedback, terminal, idle" do
      refute SessionStateMachine.task_running?(:queued)
      refute SessionStateMachine.task_running?(:awaiting_feedback)
      refute SessionStateMachine.task_running?(:completed)
      refute SessionStateMachine.task_running?(:failed)
      refute SessionStateMachine.task_running?(:cancelled)
      refute SessionStateMachine.task_running?(:idle)
      refute SessionStateMachine.task_running?(:unknown)
    end
  end

  describe "warming?/1" do
    test "returns true only for warming" do
      assert SessionStateMachine.warming?(:warming)
      refute SessionStateMachine.warming?(:running)
      refute SessionStateMachine.warming?(:queued_warm)
    end
  end

  describe "queued_cold?/1" do
    test "returns true only for queued_cold" do
      assert SessionStateMachine.queued_cold?(:queued_cold)
      refute SessionStateMachine.queued_cold?(:queued_warm)
      refute SessionStateMachine.queued_cold?(:queued)
    end
  end

  describe "queued_warm?/1" do
    test "returns true only for queued_warm" do
      assert SessionStateMachine.queued_warm?(:queued_warm)
      refute SessionStateMachine.queued_warm?(:queued_cold)
      refute SessionStateMachine.queued_warm?(:queued)
    end
  end

  describe "active?/1" do
    test "returns true for all non-terminal, non-idle states" do
      assert SessionStateMachine.active?(:queued_cold)
      assert SessionStateMachine.active?(:queued_warm)
      assert SessionStateMachine.active?(:warming)
      assert SessionStateMachine.active?(:pending)
      assert SessionStateMachine.active?(:starting)
      assert SessionStateMachine.active?(:running)
      assert SessionStateMachine.active?(:queued)
      assert SessionStateMachine.active?(:awaiting_feedback)
    end

    test "returns false for terminal states, idle, and unknown" do
      refute SessionStateMachine.active?(:completed)
      refute SessionStateMachine.active?(:failed)
      refute SessionStateMachine.active?(:cancelled)
      refute SessionStateMachine.active?(:idle)
      refute SessionStateMachine.active?(:unknown)
    end
  end

  describe "terminal?/1" do
    test "returns true for completed, failed, cancelled" do
      assert SessionStateMachine.terminal?(:completed)
      assert SessionStateMachine.terminal?(:failed)
      assert SessionStateMachine.terminal?(:cancelled)
    end

    test "returns false for active states, idle, and unknown" do
      refute SessionStateMachine.terminal?(:pending)
      refute SessionStateMachine.terminal?(:starting)
      refute SessionStateMachine.terminal?(:running)
      refute SessionStateMachine.terminal?(:queued)
      refute SessionStateMachine.terminal?(:awaiting_feedback)
      refute SessionStateMachine.terminal?(:idle)
      refute SessionStateMachine.terminal?(:unknown)
    end
  end

  describe "can_submit_message?/1" do
    test "returns true for running task" do
      assert SessionStateMachine.can_submit_message?(:running)
    end

    test "returns true for queued task — messages queue as follow-ups" do
      assert SessionStateMachine.can_submit_message?(:queued)
    end

    test "returns true for awaiting_feedback — user can still send messages" do
      assert SessionStateMachine.can_submit_message?(:awaiting_feedback)
    end

    test "returns true for pending and starting — task is spinning up" do
      assert SessionStateMachine.can_submit_message?(:pending)
      assert SessionStateMachine.can_submit_message?(:starting)
    end

    test "returns true for queued_cold, queued_warm, and warming" do
      assert SessionStateMachine.can_submit_message?(:queued_cold)
      assert SessionStateMachine.can_submit_message?(:queued_warm)
      assert SessionStateMachine.can_submit_message?(:warming)
    end

    test "returns false for terminal states" do
      refute SessionStateMachine.can_submit_message?(:completed)
      refute SessionStateMachine.can_submit_message?(:failed)
      refute SessionStateMachine.can_submit_message?(:cancelled)
    end

    test "returns false for idle and unknown" do
      refute SessionStateMachine.can_submit_message?(:idle)
      refute SessionStateMachine.can_submit_message?(:unknown)
    end
  end

  describe "submission_route/1" do
    test "routes running tasks to :follow_up" do
      assert SessionStateMachine.submission_route(:running) == :follow_up
    end

    test "routes pending and starting tasks to :follow_up — already in pipeline" do
      assert SessionStateMachine.submission_route(:pending) == :follow_up
      assert SessionStateMachine.submission_route(:warming) == :follow_up
      assert SessionStateMachine.submission_route(:starting) == :follow_up
    end

    test "routes queued_cold and queued_warm tasks to :follow_up" do
      assert SessionStateMachine.submission_route(:queued_cold) == :follow_up
      assert SessionStateMachine.submission_route(:queued_warm) == :follow_up
    end

    test "routes queued tasks to :follow_up — fixes the gap where queued fell through" do
      assert SessionStateMachine.submission_route(:queued) == :follow_up
    end

    test "routes awaiting_feedback to :follow_up" do
      assert SessionStateMachine.submission_route(:awaiting_feedback) == :follow_up
    end

    test "routes terminal states to :new_or_resume" do
      assert SessionStateMachine.submission_route(:completed) == :new_or_resume
      assert SessionStateMachine.submission_route(:failed) == :new_or_resume
      assert SessionStateMachine.submission_route(:cancelled) == :new_or_resume
    end

    test "routes idle to :new_or_resume" do
      assert SessionStateMachine.submission_route(:idle) == :new_or_resume
    end

    test "routes unknown to :blocked" do
      assert SessionStateMachine.submission_route(:unknown) == :blocked
    end
  end

  describe "display_name/1" do
    test "returns the domain-consistent lifecycle label" do
      assert SessionStateMachine.display_name(:queued_cold) == "Queued (cold)"
      assert SessionStateMachine.display_name(:queued_warm) == "Queued (warm)"
      assert SessionStateMachine.display_name(:warming) == "Warming up"
    end
  end

  describe "resumable?/1 — convenience that checks task struct" do
    test "returns true for terminal task with container_id and session_id" do
      task = %{status: "completed", container_id: "cid-1", session_id: "sid-1"}
      assert SessionStateMachine.resumable?(task)

      task = %{status: "failed", container_id: "cid-1", session_id: "sid-1"}
      assert SessionStateMachine.resumable?(task)

      task = %{status: "cancelled", container_id: "cid-1", session_id: "sid-1"}
      assert SessionStateMachine.resumable?(task)
    end

    test "returns false for terminal task without container_id" do
      task = %{status: "completed", container_id: nil, session_id: "sid-1"}
      refute SessionStateMachine.resumable?(task)
    end

    test "returns false for terminal task without session_id" do
      task = %{status: "completed", container_id: "cid-1", session_id: nil}
      refute SessionStateMachine.resumable?(task)
    end

    test "returns false for active tasks" do
      task = %{status: "running", container_id: "cid-1", session_id: "sid-1"}
      refute SessionStateMachine.resumable?(task)
    end

    test "returns false for nil task" do
      refute SessionStateMachine.resumable?(nil)
    end
  end
end
