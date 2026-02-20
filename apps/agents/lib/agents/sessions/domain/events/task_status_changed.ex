defmodule Agents.Sessions.Domain.Events.TaskStatusChanged do
  @moduledoc """
  Domain event emitted when a task's status changes.
  """

  use Perme8.Events.DomainEvent,
    aggregate_type: "task",
    fields: [task_id: nil, old_status: nil, new_status: nil],
    required: [:task_id, :old_status, :new_status]
end
