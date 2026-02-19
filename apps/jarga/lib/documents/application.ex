defmodule Jarga.Documents.Application do
  @moduledoc """
  Application layer boundary for the Documents context.

  Contains orchestration logic that coordinates domain and infrastructure:

  ## Use Cases
  - `UseCases.CreateDocument` - Document creation flow
  - `UseCases.UpdateDocument` - Document update flow
  - `UseCases.DeleteDocument` - Document deletion flow
  - `UseCases.ExecuteAgentQuery` - Agent query execution flow
  - `UseCases.UseCase` - Base use case behaviour

  ## Policies
  - `Policies.DocumentAuthorizationPolicy` - Document authorization rules

  ## Dependency Rule

  The Application layer may only depend on:
  - Domain layer (same context)

  It cannot import:
  - Infrastructure layer (repos, schemas, notifiers)
  - Other contexts directly (use dependency injection)
  """

  use Boundary,
    top_level?: true,
    deps: [
      Jarga.Documents.Domain,
      Perme8.Events,
      # Cross-context dependencies
      Identity,
      Jarga.Accounts,
      Jarga.Domain,
      Jarga.Workspaces,
      Agents
      # Note: Infrastructure modules are referenced via @default_* attributes for DI
      # but we don't declare them as deps to avoid dependency cycle.
      # The references are compile-time only (module attributes) and resolved at runtime.
    ],
    exports: [
      UseCases.CreateDocument,
      UseCases.UpdateDocument,
      UseCases.DeleteDocument,
      UseCases.ExecuteAgentQuery,
      UseCases.UseCase,
      Policies.DocumentAuthorizationPolicy,
      Services.NotificationService,
      # Behaviours (interfaces for Infrastructure to implement)
      Behaviours.AuthorizationRepositoryBehaviour,
      Behaviours.DocumentComponentSchemaBehaviour,
      Behaviours.DocumentRepositoryBehaviour,
      Behaviours.DocumentSchemaBehaviour
    ]
end
