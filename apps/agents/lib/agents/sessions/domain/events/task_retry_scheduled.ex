defmodule Agents.Sessions.Domain.Events.TaskRetryScheduled do
  @moduledoc """
  Domain event emitted when retry scheduling is created for a task.
  """

  use Perme8.Events.DomainEvent,
    aggregate_type: "task",
    fields: [task_id: nil, user_id: nil, retry_count: nil, next_retry_at: nil],
    required: [:task_id, :user_id, :retry_count, :next_retry_at]
end
