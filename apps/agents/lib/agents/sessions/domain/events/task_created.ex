defmodule Agents.Sessions.Domain.Events.TaskCreated do
  @moduledoc """
  Domain event emitted when a coding task is created.
  """

  use Perme8.Events.DomainEvent,
    aggregate_type: "task",
    fields: [task_id: nil, user_id: nil, instruction: nil],
    required: [:task_id, :user_id, :instruction]
end
