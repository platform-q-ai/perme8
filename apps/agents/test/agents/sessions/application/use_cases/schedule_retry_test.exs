defmodule Agents.Sessions.Application.UseCases.ScheduleRetryMockTaskRepo do
  def update_task_status(task, attrs) do
    send(self(), {:update_task_status, task.id, attrs})
    {:ok, Map.merge(task, attrs)}
  end
end

defmodule Agents.Sessions.Application.UseCases.ScheduleRetryMockEventBus do
  def emit(event) do
    send(self(), {:emit, event})
    :ok
  end
end

defmodule Agents.Sessions.Application.UseCases.ScheduleRetryTest do
  use ExUnit.Case, async: true

  alias Agents.Sessions.Application.UseCases.ScheduleRetry
  alias Agents.Sessions.Domain.Events.{TaskLaneChanged, TaskRetryScheduled}

  describe "execute/2" do
    test "retryable failure increments retry_count and schedules retry" do
      task = %{id: "task-1", user_id: "user-1", error: "runner_start_failed", retry_count: 0}

      assert {:ok, :retrying} =
               ScheduleRetry.execute(task,
                 task_repo: Agents.Sessions.Application.UseCases.ScheduleRetryMockTaskRepo,
                 event_bus: Agents.Sessions.Application.UseCases.ScheduleRetryMockEventBus
               )

      assert_receive {:update_task_status, "task-1", attrs}
      assert attrs.status == "queued"
      assert attrs.retry_count == 1
      assert %DateTime{} = attrs.last_retry_at
      assert %DateTime{} = attrs.next_retry_at
    end

    test "non-retryable failure marks permanently failed" do
      task = %{id: "task-1", user_id: "user-1", error: "validation_error", retry_count: 0}

      assert {:ok, :permanently_failed} =
               ScheduleRetry.execute(task,
                 task_repo: Agents.Sessions.Application.UseCases.ScheduleRetryMockTaskRepo,
                 event_bus: Agents.Sessions.Application.UseCases.ScheduleRetryMockEventBus
               )

      assert_receive {:update_task_status, "task-1", attrs}
      assert attrs.status == "failed"
      assert attrs.error == "retry_exhausted: validation_error"
    end

    test "retry exhausted marks permanently failed" do
      task = %{id: "task-1", user_id: "user-1", error: "runner_start_failed", retry_count: 3}

      assert {:ok, :permanently_failed} =
               ScheduleRetry.execute(task,
                 task_repo: Agents.Sessions.Application.UseCases.ScheduleRetryMockTaskRepo,
                 event_bus: Agents.Sessions.Application.UseCases.ScheduleRetryMockEventBus
               )

      assert_receive {:update_task_status, "task-1", attrs}
      assert attrs.status == "failed"
      assert attrs.error == "retry_exhausted: runner_start_failed"
    end

    test "emits TaskRetryScheduled and TaskLaneChanged events on retry" do
      task = %{id: "task-1", user_id: "user-1", error: "runner_start_failed", retry_count: 0}

      assert {:ok, :retrying} =
               ScheduleRetry.execute(task,
                 task_repo: Agents.Sessions.Application.UseCases.ScheduleRetryMockTaskRepo,
                 event_bus: Agents.Sessions.Application.UseCases.ScheduleRetryMockEventBus
               )

      assert_receive {:emit, %TaskRetryScheduled{} = retry_event}
      assert retry_event.task_id == "task-1"
      assert retry_event.user_id == "user-1"
      assert retry_event.retry_count == 1

      assert_receive {:emit, %TaskLaneChanged{} = lane_event}
      assert lane_event.task_id == "task-1"
      assert lane_event.from_lane == :processing
      assert lane_event.to_lane == :retry_pending
    end

    test "does not emit events on permanent failure" do
      task = %{id: "task-1", user_id: "user-1", error: "validation_error", retry_count: 0}

      assert {:ok, :permanently_failed} =
               ScheduleRetry.execute(task,
                 task_repo: Agents.Sessions.Application.UseCases.ScheduleRetryMockTaskRepo,
                 event_bus: Agents.Sessions.Application.UseCases.ScheduleRetryMockEventBus
               )

      refute_received {:emit, _}
    end

    test "calculates next_retry_at from backoff delay" do
      task = %{id: "task-1", user_id: "user-1", error: "runner_start_failed", retry_count: 1}

      assert {:ok, :retrying} =
               ScheduleRetry.execute(task,
                 task_repo: Agents.Sessions.Application.UseCases.ScheduleRetryMockTaskRepo,
                 event_bus: Agents.Sessions.Application.UseCases.ScheduleRetryMockEventBus
               )

      assert_receive {:update_task_status, "task-1", attrs}

      delay_ms = DateTime.diff(attrs.next_retry_at, attrs.last_retry_at, :millisecond)
      assert delay_ms >= 24_900
      assert delay_ms <= 25_100
    end
  end
end
