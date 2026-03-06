defmodule Agents.Sessions.Application.UseCases.ScheduleRetry do
  @moduledoc """
  Use case that schedules a retry for a failed task, or marks it as permanently failed.

  Delegates retry eligibility to RetryPolicy and emits appropriate events.
  """

  alias Agents.Sessions.Domain.Events.{TaskLaneChanged, TaskRetryScheduled}
  alias Agents.Sessions.Domain.Policies.RetryPolicy

  @default_task_repo Agents.Sessions.Infrastructure.Repositories.TaskRepository
  @default_event_bus Perme8.Events.EventBus

  @spec execute(map(), keyword()) :: {:ok, :retrying | :permanently_failed}
  def execute(task, opts \\ []) do
    task_repo = Keyword.get(opts, :task_repo, @default_task_repo)
    event_bus = Keyword.get(opts, :event_bus, @default_event_bus)

    retry_info = %{
      error: task.error,
      retry_count: Map.get(task, :retry_count, 0)
    }

    if RetryPolicy.retryable?(retry_info) do
      schedule_retry(task, retry_info, task_repo, event_bus)
    else
      mark_permanently_failed(task, task_repo)
    end
  end

  defp schedule_retry(task, retry_info, task_repo, event_bus) do
    new_count = retry_info.retry_count + 1
    delay_ms = RetryPolicy.next_retry_delay(retry_info.retry_count)
    next_retry_at = DateTime.add(DateTime.utc_now(), delay_ms, :millisecond)

    {:ok, _updated} =
      task_repo.update_task_status(task, %{
        status: "queued",
        retry_count: new_count,
        last_retry_at: DateTime.utc_now(),
        next_retry_at: next_retry_at
      })

    event_bus.emit(
      TaskRetryScheduled.new(%{
        aggregate_id: task.id,
        actor_id: task.user_id,
        task_id: task.id,
        user_id: task.user_id,
        retry_count: new_count,
        next_retry_at: next_retry_at
      })
    )

    event_bus.emit(
      TaskLaneChanged.new(%{
        aggregate_id: task.id,
        actor_id: task.user_id,
        task_id: task.id,
        user_id: task.user_id,
        from_lane: :processing,
        to_lane: :retry_pending
      })
    )

    {:ok, :retrying}
  end

  defp mark_permanently_failed(task, task_repo) do
    {:ok, _updated} =
      task_repo.update_task_status(task, %{
        status: "failed",
        error: "retry_exhausted: #{task.error}"
      })

    {:ok, :permanently_failed}
  end
end
