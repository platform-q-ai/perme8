defmodule EntityRelationshipManager.ApplicationLayer do
  @moduledoc """
  Application layer boundary for the Entity Relationship Manager.

  The application layer orchestrates business operations by:

  - Coordinating domain entities and policies
  - Defining use cases (single-responsibility operations)
  - Depending on abstractions (behaviours) for infrastructure
  - Supporting dependency injection for testability

  ## Dependency Rules

  Application layer modules:
  - MUST depend only on domain layer entities and policies
  - MUST use dependency injection for infrastructure concerns
  - MUST NOT directly call Repo, Neo4j, or external services
  - MAY define behaviours for infrastructure implementations
  """

  # Note: The application layer boundary is enforced on
  # EntityRelationshipManager.Application (OTP application module)
  # which governs the Application.UseCases.* and Application.Behaviours.* namespaces.
  # This module serves as documentation and introspection for the layer.

  @doc """
  Lists all use case modules in the ERM application.
  """
  @spec use_cases() :: [module()]
  def use_cases do
    [
      EntityRelationshipManager.Application.UseCases.GetSchema,
      EntityRelationshipManager.Application.UseCases.UpsertSchema,
      EntityRelationshipManager.Application.UseCases.CreateEntity,
      EntityRelationshipManager.Application.UseCases.GetEntity,
      EntityRelationshipManager.Application.UseCases.ListEntities,
      EntityRelationshipManager.Application.UseCases.UpdateEntity,
      EntityRelationshipManager.Application.UseCases.DeleteEntity,
      EntityRelationshipManager.Application.UseCases.CreateEdge,
      EntityRelationshipManager.Application.UseCases.GetEdge,
      EntityRelationshipManager.Application.UseCases.ListEdges,
      EntityRelationshipManager.Application.UseCases.UpdateEdge,
      EntityRelationshipManager.Application.UseCases.DeleteEdge,
      EntityRelationshipManager.Application.UseCases.GetNeighbors,
      EntityRelationshipManager.Application.UseCases.FindPaths,
      EntityRelationshipManager.Application.UseCases.Traverse,
      EntityRelationshipManager.Application.UseCases.BulkCreateEntities,
      EntityRelationshipManager.Application.UseCases.BulkUpdateEntities,
      EntityRelationshipManager.Application.UseCases.BulkDeleteEntities,
      EntityRelationshipManager.Application.UseCases.BulkCreateEdges
    ]
  end

  @doc """
  Lists all behaviour modules defined in the ERM application layer.
  """
  @spec behaviours() :: [module()]
  def behaviours do
    [
      EntityRelationshipManager.Application.Behaviours.SchemaRepositoryBehaviour,
      EntityRelationshipManager.Application.Behaviours.GraphRepositoryBehaviour
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
