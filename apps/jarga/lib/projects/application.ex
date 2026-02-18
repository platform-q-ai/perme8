defmodule Jarga.Projects.Application do
  @moduledoc """
  Application layer boundary for the Projects context.

  Contains orchestration logic that coordinates domain and infrastructure:

  ## Use Cases
  - `UseCases.CreateProject` - Project creation flow
  - `UseCases.UpdateProject` - Project update flow
  - `UseCases.DeleteProject` - Project deletion flow
  - `UseCases.UseCase` - Base use case behaviour

  ## Services
  - `Services.NotificationService` - Project notification service

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
      Jarga.Projects.Domain,
      Perme8.Events,
      # Cross-context dependencies
      Identity,
      Jarga.Accounts,
      Jarga.Domain,
      Jarga.Workspaces
    ],
    exports: [
      UseCases.CreateProject,
      UseCases.UpdateProject,
      UseCases.DeleteProject,
      UseCases.UseCase,
      Services.NotificationService,
      # Behaviours (interfaces for Infrastructure to implement)
      Behaviours.AuthorizationRepositoryBehaviour,
      Behaviours.NotificationServiceBehaviour,
      Behaviours.ProjectRepositoryBehaviour
    ]
end
