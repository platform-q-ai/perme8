defmodule Agents.Sessions.Domain.Events.TaskCancelled do
  @moduledoc """
  Domain event emitted when a coding task is cancelled by the user.
  """

  use Perme8.Events.DomainEvent,
    aggregate_type: "task",
    fields: [task_id: nil, user_id: nil],
    required: [:task_id, :user_id]
end
