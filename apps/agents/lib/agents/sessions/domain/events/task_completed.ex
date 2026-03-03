defmodule Agents.Sessions.Domain.Events.TaskCompleted do
  @moduledoc """
  Domain event emitted when a coding task completes successfully.
  """

  use Perme8.Events.DomainEvent,
    aggregate_type: "task",
    fields: [task_id: nil, user_id: nil, target_user_id: nil, instruction: nil],
    required: [:task_id, :user_id, :target_user_id]
end
