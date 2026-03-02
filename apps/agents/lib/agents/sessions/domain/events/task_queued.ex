defmodule Agents.Sessions.Domain.Events.TaskQueued do
  @moduledoc """
  Domain event emitted when a task is queued due to concurrency limits.
  """

  use Perme8.Events.DomainEvent,
    aggregate_type: "task",
    fields: [task_id: nil, user_id: nil, queue_position: nil],
    required: [:task_id, :user_id, :queue_position]
end
