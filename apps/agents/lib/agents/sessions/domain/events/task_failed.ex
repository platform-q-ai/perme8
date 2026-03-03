defmodule Agents.Sessions.Domain.Events.TaskFailed do
  @moduledoc """
  Domain event emitted when a coding task fails.
  """

  use Perme8.Events.DomainEvent,
    aggregate_type: "task",
    fields: [task_id: nil, user_id: nil, target_user_id: nil, instruction: nil, error: nil],
    required: [:task_id, :user_id, :target_user_id]
end
