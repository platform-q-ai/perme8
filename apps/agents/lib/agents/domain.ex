defmodule Agents.Domain do
  @moduledoc """
  Domain layer boundary for the Agents context.

  Contains pure business logic with no external dependencies:
  - Entities: Agent, WorkspaceAgentJoin
  - Domain services: AgentCloner
  """

  use Boundary,
    top_level?: true,
    deps: [],
    exports: [
      Entities.Agent,
      Entities.WorkspaceAgentJoin,
      Entities.KnowledgeEntry,
      Entities.KnowledgeRelationship,
      AgentCloner,
      Policies.KnowledgeValidationPolicy,
      Policies.SearchPolicy,
      Events.AgentCreated,
      Events.AgentUpdated,
      Events.AgentDeleted,
      Events.AgentAddedToWorkspace,
      Events.AgentRemovedFromWorkspace
    ]
end
