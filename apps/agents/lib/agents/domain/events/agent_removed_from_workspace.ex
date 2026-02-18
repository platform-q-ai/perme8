defmodule Agents.Domain.Events.AgentRemovedFromWorkspace do
  @moduledoc """
  Domain event emitted when an agent is removed from a workspace.
  """

  use Perme8.Events.DomainEvent,
    aggregate_type: "agent",
    fields: [agent_id: nil, user_id: nil],
    required: [:agent_id, :workspace_id, :user_id]
end
