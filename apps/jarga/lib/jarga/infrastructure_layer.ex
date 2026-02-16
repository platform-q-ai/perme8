defmodule Jarga.InfrastructureLayer do
  @moduledoc """
  Infrastructure layer namespace for the Jarga application.

  Jarga uses a **Bounded Context** architecture where each context
  has its own infrastructure layer with repositories, schemas, queries,
  and external service integrations.

  Note: User/account infrastructure is in the separate `Identity` app.
  See `Identity.Infrastructure` for user schemas, repositories, etc.

  This module provides documentation and introspection for all infrastructure
  layer modules across Jarga contexts.

  ## Infrastructure Layer Principles

  The infrastructure layer handles all external concerns:

  - **Repositories** - Data persistence via Ecto
  - **Schemas** - Ecto schemas for database mapping
  - **Queries** - Reusable Ecto query builders
  - **Notifiers** - Email, PubSub, and push notifications
  - **External Services** - API clients, LLM integrations

  ## Dependency Rules

  Infrastructure layer modules:
  - MUST implement behaviours defined in the application layer
  - MAY depend on domain entities for data mapping
  - MAY use external libraries (Ecto, Swoosh, Req, etc.)
  - MUST NOT contain business logic (delegate to domain/application)
  """

  @doc """
  Lists all known repository modules across all Jarga contexts.

  Note: User repositories are in the Identity app.

  ## Examples

      iex> Jarga.InfrastructureLayer.repositories()
      [Agents.Infrastructure.Repositories.AgentRepository, ...]
  """
  @spec repositories() :: [module()]
  def repositories do
    [
      # Agents (extracted to apps/agents/)
      Agents.Infrastructure.Repositories.AgentRepository,
      Agents.Infrastructure.Repositories.WorkspaceAgentRepository,
      # Chat
      Jarga.Chat.Infrastructure.Repositories.SessionRepository,
      Jarga.Chat.Infrastructure.Repositories.MessageRepository,
      # Documents
      Jarga.Documents.Infrastructure.Repositories.DocumentRepository,
      Jarga.Documents.Infrastructure.Repositories.AuthorizationRepository,
      Jarga.Documents.Notes.Infrastructure.Repositories.NoteRepository,
      Jarga.Documents.Notes.Infrastructure.Repositories.AuthorizationRepository,
      # Notifications
      Jarga.Notifications.Infrastructure.Repositories.NotificationRepository,
      # Projects
      Jarga.Projects.Infrastructure.Repositories.ProjectRepository,
      Jarga.Projects.Infrastructure.Repositories.AuthorizationRepository
      # Workspaces — migrated to Identity app
    ]
  end

  @doc """
  Lists all known schema modules across all Jarga contexts.

  Note: User schemas are in the Identity app (`Identity.Infrastructure.Schemas.UserSchema`).

  ## Examples

      iex> Jarga.InfrastructureLayer.schemas()
      [Agents.Infrastructure.Schemas.AgentSchema, ...]
  """
  @spec schemas() :: [module()]
  def schemas do
    [
      # Agents (extracted to apps/agents/)
      Agents.Infrastructure.Schemas.AgentSchema,
      Agents.Infrastructure.Schemas.WorkspaceAgentJoinSchema,
      # Chat
      Jarga.Chat.Infrastructure.Schemas.SessionSchema,
      Jarga.Chat.Infrastructure.Schemas.MessageSchema,
      # Documents
      Jarga.Documents.Infrastructure.Schemas.DocumentSchema,
      Jarga.Documents.Infrastructure.Schemas.DocumentComponentSchema,
      Jarga.Documents.Notes.Infrastructure.Schemas.NoteSchema,
      # Notifications
      Jarga.Notifications.Infrastructure.Schemas.NotificationSchema,
      # Projects
      Jarga.Projects.Infrastructure.Schemas.ProjectSchema
      # Workspaces — migrated to Identity app
    ]
  end

  @doc """
  Lists all known query modules across all Jarga contexts.

  ## Examples

      iex> Jarga.InfrastructureLayer.queries()
      [Agents.Infrastructure.Queries.AgentQueries, ...]
  """
  @spec queries() :: [module()]
  def queries do
    [
      # Agents (extracted to apps/agents/)
      Agents.Infrastructure.Queries.AgentQueries,
      # Chat
      Jarga.Chat.Infrastructure.Queries.Queries,
      # Documents
      Jarga.Documents.Infrastructure.Queries.DocumentQueries,
      Jarga.Documents.Notes.Infrastructure.Queries.Queries,
      # Projects
      Jarga.Projects.Infrastructure.Queries.Queries
      # Workspaces — migrated to Identity app
    ]
  end

  @doc """
  Lists all known notifier modules across all Jarga contexts.

  Note: User notifiers are in the Identity app.

  ## Examples

      iex> Jarga.InfrastructureLayer.notifiers()
      [Agents.Infrastructure.Notifiers.PubSubNotifier, ...]
  """
  @spec notifiers() :: [module()]
  def notifiers do
    [
      # Agents (extracted to apps/agents/)
      Agents.Infrastructure.Notifiers.PubSubNotifier,
      # Documents
      Jarga.Documents.Infrastructure.Notifiers.PubSubNotifier,
      # Notifications
      Jarga.Notifications.Infrastructure.Notifiers.PubSubNotifier,
      # Projects
      Jarga.Projects.Infrastructure.Notifiers.EmailAndPubSubNotifier
      # Workspaces — migrated to Identity app
    ]
  end

  @doc """
  Lists all known external service modules across all Jarga contexts.

  ## Examples

      iex> Jarga.InfrastructureLayer.external_services()
      [Agents.Infrastructure.Services.LlmClient, ...]
  """
  @spec external_services() :: [module()]
  def external_services do
    [
      # Agents (extracted to apps/agents/)
      Agents.Infrastructure.Services.LlmClient
    ]
  end

  @doc """
  Returns a count summary of infrastructure layer modules.

  ## Examples

      iex> Jarga.InfrastructureLayer.summary()
      %{repositories: 13, schemas: 11, queries: 6, notifiers: 7, services: 1, total: 38}
  """
  @spec summary() :: map()
  def summary do
    repo_count = length(repositories())
    schema_count = length(schemas())
    query_count = length(queries())
    notifier_count = length(notifiers())
    service_count = length(external_services())

    %{
      repositories: repo_count,
      schemas: schema_count,
      queries: query_count,
      notifiers: notifier_count,
      services: service_count,
      total: repo_count + schema_count + query_count + notifier_count + service_count
    }
  end
end
