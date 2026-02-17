defmodule KnowledgeMcp.ApplicationLayer do
  @moduledoc """
  Application layer boundary for the Knowledge MCP bounded context.

  The application layer orchestrates business operations by:

  - Coordinating domain entities and policies
  - Defining use cases (single-responsibility operations)
  - Depending on abstractions (behaviours) for infrastructure
  - Supporting dependency injection for testability

  ## Dependency Rules

  Application layer modules:
  - MUST depend only on domain layer entities and policies
  - MUST use dependency injection for infrastructure concerns
  - MUST NOT directly call external services without abstractions
  - MAY define behaviours for infrastructure implementations
  """

  use Boundary, top_level?: true, deps: [], exports: []

  @doc """
  Lists all use case modules in the Knowledge MCP application.
  """
  @spec use_cases() :: [module()]
  def use_cases do
    [
      KnowledgeMcp.Application.UseCases.AuthenticateRequest,
      KnowledgeMcp.Application.UseCases.BootstrapKnowledgeSchema,
      KnowledgeMcp.Application.UseCases.CreateKnowledgeEntry,
      KnowledgeMcp.Application.UseCases.CreateKnowledgeRelationship,
      KnowledgeMcp.Application.UseCases.GetKnowledgeEntry,
      KnowledgeMcp.Application.UseCases.SearchKnowledgeEntries,
      KnowledgeMcp.Application.UseCases.TraverseKnowledgeGraph,
      KnowledgeMcp.Application.UseCases.UpdateKnowledgeEntry
    ]
  end

  @doc """
  Lists all behaviour modules defined in the application layer.
  """
  @spec behaviours() :: [module()]
  def behaviours do
    [
      KnowledgeMcp.Application.Behaviours.ErmGatewayBehaviour,
      KnowledgeMcp.Application.Behaviours.IdentityBehaviour
    ]
  end

  @doc """
  Returns a count summary of application layer modules.
  """
  @spec summary() :: map()
  def summary do
    use_case_count = length(use_cases())
    behaviour_count = length(behaviours())

    %{
      use_cases: use_case_count,
      behaviours: behaviour_count,
      total: use_case_count + behaviour_count
    }
  end
end
