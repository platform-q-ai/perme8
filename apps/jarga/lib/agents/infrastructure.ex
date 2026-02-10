defmodule Jarga.Agents.Infrastructure do
  @moduledoc """
  Infrastructure layer boundary for the Agents context.

  Contains implementation details for persistence and external services:
  - Schemas: AgentSchema, WorkspaceAgentJoinSchema
  - Repositories: AgentRepository, WorkspaceAgentRepository
  - Services: LlmClient
  - Queries: AgentQueries
  - Notifiers: PubSubNotifier
  """

  use Boundary,
    top_level?: true,
    deps: [
      Jarga.Agents.Domain,
      Jarga.Agents.Application,
      Jarga.Repo,
      # Cross-context dependencies
      Identity,
      Identity.Repo,
      Jarga.Accounts,
      Jarga.Workspaces,
      Jarga.Workspaces.Infrastructure
    ],
    exports: [
      # Schemas
      Schemas.AgentSchema,
      Schemas.WorkspaceAgentJoinSchema,
      # Repositories
      Repositories.AgentRepository,
      Repositories.WorkspaceAgentRepository,
      # Services
      Services.LlmClient,
      # Queries
      Queries.AgentQueries,
      # Notifiers
      Notifiers.PubSubNotifier
    ]
end
