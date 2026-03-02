defmodule Agents.Sessions.Domain.Events.TaskDeprioritised do
  @moduledoc """
  Domain event emitted when a running task is deprioritised due to awaiting human feedback.
  """

  use Perme8.Events.DomainEvent,
    aggregate_type: "task",
    fields: [task_id: nil, user_id: nil, queue_position: nil],
    required: [:task_id, :user_id, :queue_position]
end
