defmodule Agents.Infrastructure do
  @moduledoc """
  Infrastructure layer boundary for the Agents context.

  Contains implementation details for persistence and external services:
  - Schemas: AgentSchema, WorkspaceAgentJoinSchema
  - Repositories: AgentRepository, WorkspaceAgentRepository
  - Services: LlmClient
  - Queries: AgentQueries
  - Notifiers: PubSubNotifier
  - Gateways: ErmGateway (delegates to EntityRelationshipManager)
  - MCP: Server, Router, AuthPlug, and 6 tool components
  """

  use Boundary,
    top_level?: true,
    deps: [
      Agents.Domain,
      Agents.Application,
      # Cross-context dependencies (cross-app modules resolved at runtime)
      Identity,
      Identity.Repo
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
      Notifiers.PubSubNotifier,
      # Knowledge MCP
      Gateways.ErmGateway,
      Gateways.JargaGateway,
      Mcp.Server,
      Mcp.Router,
      Mcp.AuthPlug
    ]
end
