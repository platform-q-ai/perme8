defmodule Jarga.Workspaces.Infrastructure do
  @moduledoc """
  Infrastructure layer boundary for the Workspaces context.

  Contains implementations that interact with external systems:

  ## Schemas (Database Representation)
  - `Schemas.WorkspaceSchema` - Ecto schema for workspaces table
  - `Schemas.WorkspaceMemberSchema` - Ecto schema for workspace members

  ## Repositories (Data Access)
  - `Repositories.WorkspaceRepository` - Workspace persistence operations
  - `Repositories.MembershipRepository` - Membership persistence operations

  ## Queries (Ecto Query Builders)
  - `Queries.Queries` - Workspace query operations

  ## Notifiers (External Communication)
  - `Notifiers.EmailAndPubSubNotifier` - Email and PubSub notifications
  - `Notifiers.PubSubNotifier` - PubSub-only notifications
  - `Notifiers.WorkspaceNotifier` - Workspace-specific notifications

  ## Dependency Rule

  The Infrastructure layer may depend on:
  - Domain layer (for entities and policies)
  - Application layer (to implement service behaviours)
  - Shared infrastructure (Repo, Mailer)

  It can use external libraries (Ecto, Swoosh, Phoenix.PubSub, etc.)
  """

  use Boundary,
    top_level?: true,
    deps: [
      Jarga.Workspaces.Domain,
      Jarga.Workspaces.Application,
      Jarga.Repo,
      Jarga.Mailer,
      # Cross-context dependencies (context + domain/infrastructure layer for entity access)
      Jarga.Accounts,
      Jarga.Accounts.Domain,
      Jarga.Accounts.Infrastructure
    ],
    exports: [
      Schemas.WorkspaceSchema,
      Schemas.WorkspaceMemberSchema,
      Repositories.WorkspaceRepository,
      Repositories.MembershipRepository,
      Queries.Queries,
      Notifiers.EmailAndPubSubNotifier,
      Notifiers.PubSubNotifier,
      Notifiers.WorkspaceNotifier
    ]
end
