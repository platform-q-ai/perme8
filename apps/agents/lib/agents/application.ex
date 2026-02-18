defmodule Agents.Application do
  @moduledoc """
  Application layer boundary for the Agents context.

  Contains use cases and policies that orchestrate domain logic:
  - Use cases: CRUD operations, queries, workspace management
  - Policies: AgentPolicy, VisibilityPolicy
  """

  use Boundary,
    top_level?: true,
    deps: [Agents.Domain, Identity],
    exports: [
      # Use cases
      UseCases.AddAgentToWorkspace,
      UseCases.AgentQuery,
      UseCases.CloneSharedAgent,
      UseCases.CreateUserAgent,
      UseCases.DeleteUserAgent,
      UseCases.ListUserAgents,
      UseCases.ListViewableAgents,
      UseCases.ListWorkspaceAvailableAgents,
      UseCases.RemoveAgentFromWorkspace,
      UseCases.SyncAgentWorkspaces,
      UseCases.UpdateUserAgent,
      UseCases.ValidateAgentParams,
      # Knowledge use cases
      UseCases.AuthenticateMcpRequest,
      UseCases.BootstrapKnowledgeSchema,
      UseCases.CreateKnowledgeEntry,
      UseCases.UpdateKnowledgeEntry,
      UseCases.GetKnowledgeEntry,
      UseCases.SearchKnowledgeEntries,
      UseCases.TraverseKnowledgeGraph,
      UseCases.CreateKnowledgeRelationship,
      # Policies
      Policies.AgentPolicy,
      Policies.VisibilityPolicy,
      # Behaviours (interfaces for Infrastructure to implement)
      Behaviours.AgentRepositoryBehaviour,
      Behaviours.AgentSchemaBehaviour,
      Behaviours.LlmClientBehaviour,
      Behaviours.PubSubNotifierBehaviour,
      Behaviours.WorkspaceAgentRepositoryBehaviour,
      Behaviours.ErmGatewayBehaviour,
      Behaviours.IdentityBehaviour,
      Behaviours.JargaGatewayBehaviour,
      # Config
      GatewayConfig
    ]
end
