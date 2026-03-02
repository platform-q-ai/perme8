defmodule Agents.Sessions.Domain.Events.TaskPromoted do
  @moduledoc """
  Domain event emitted when a queued task is promoted to pending.
  """

  use Perme8.Events.DomainEvent,
    aggregate_type: "task",
    fields: [task_id: nil, user_id: nil],
    required: [:task_id, :user_id]
end
