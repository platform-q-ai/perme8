defmodule Agents.Sessions.Domain.Events.TaskLaneChanged do
  @moduledoc """
  Domain event emitted when a task changes queue lane.
  """

  use Perme8.Events.DomainEvent,
    aggregate_type: "task",
    fields: [task_id: nil, user_id: nil, from_lane: nil, to_lane: nil],
    required: [:task_id, :user_id, :from_lane, :to_lane]
end
