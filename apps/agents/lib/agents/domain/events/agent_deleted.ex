defmodule Agents.Domain.Events.AgentDeleted do
  @moduledoc """
  Domain event emitted when an agent is deleted.
  """

  use Perme8.Events.DomainEvent,
    aggregate_type: "agent",
    fields: [agent_id: nil, user_id: nil, workspace_ids: []],
    required: [:agent_id, :user_id]
end
