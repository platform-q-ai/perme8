defmodule Agents.Domain.Events.AgentUpdated do
  @moduledoc """
  Domain event emitted when an agent is updated.
  """

  use Perme8.Events.DomainEvent,
    aggregate_type: "agent",
    fields: [agent_id: nil, user_id: nil, workspace_ids: [], changes: %{}],
    required: [:agent_id, :user_id]
end
