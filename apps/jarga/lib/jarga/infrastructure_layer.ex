defmodule Jarga.InfrastructureLayer do
  @moduledoc """
  Infrastructure layer namespace for the Jarga application.

  Jarga uses a **Bounded Context** architecture where each context
  has its own infrastructure layer with repositories, schemas, queries,
  and external service integrations.

  This module provides documentation and introspection for all infrastructure
  layer modules across contexts.

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
  Lists all known repository modules across all contexts.

  ## Examples

      iex> Jarga.InfrastructureLayer.repositories()
      [Jarga.Accounts.Infrastructure.Repositories.UserRepository, ...]
  """
  @spec repositories() :: [module()]
  def repositories do
    [
      # Accounts
      Jarga.Accounts.Infrastructure.Repositories.UserRepository,
      Jarga.Accounts.Infrastructure.Repositories.UserTokenRepository,
      Jarga.Accounts.Infrastructure.Repositories.ApiKeyRepository,
      # Agents
      Jarga.Agents.Infrastructure.Repositories.AgentRepository,
      Jarga.Agents.Infrastructure.Repositories.WorkspaceAgentRepository,
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
      Jarga.Projects.Infrastructure.Repositories.AuthorizationRepository,
      # Workspaces
      Jarga.Workspaces.Infrastructure.Repositories.WorkspaceRepository,
      Jarga.Workspaces.Infrastructure.Repositories.MembershipRepository
    ]
  end

  @doc """
  Lists all known schema modules across all contexts.

  ## Examples

      iex> Jarga.InfrastructureLayer.schemas()
      [Jarga.Accounts.Infrastructure.Schemas.UserSchema, ...]
  """
  @spec schemas() :: [module()]
  def schemas do
    [
      # Accounts
      Jarga.Accounts.Infrastructure.Schemas.UserSchema,
      Jarga.Accounts.Infrastructure.Schemas.UserTokenSchema,
      Jarga.Accounts.Infrastructure.Schemas.ApiKeySchema,
      # Agents
      Jarga.Agents.Infrastructure.Schemas.AgentSchema,
      Jarga.Agents.Infrastructure.Schemas.WorkspaceAgentJoinSchema,
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
      Jarga.Projects.Infrastructure.Schemas.ProjectSchema,
      # Workspaces
      Jarga.Workspaces.Infrastructure.Schemas.WorkspaceSchema,
      Jarga.Workspaces.Infrastructure.Schemas.WorkspaceMemberSchema
    ]
  end

  @doc """
  Lists all known query modules across all contexts.

  ## Examples

      iex> Jarga.InfrastructureLayer.queries()
      [Jarga.Accounts.Infrastructure.Queries.Queries, ...]
  """
  @spec queries() :: [module()]
  def queries do
    [
      # Accounts
      Jarga.Accounts.Infrastructure.Queries.Queries,
      Jarga.Accounts.Infrastructure.Queries.ApiKeyQueries,
      # Agents
      Jarga.Agents.Infrastructure.Queries.AgentQueries,
      # Chat
      Jarga.Chat.Infrastructure.Queries.Queries,
      # Documents
      Jarga.Documents.Infrastructure.Queries.DocumentQueries,
      Jarga.Documents.Notes.Infrastructure.Queries.Queries,
      # Projects
      Jarga.Projects.Infrastructure.Queries.Queries,
      # Workspaces
      Jarga.Workspaces.Infrastructure.Queries.Queries
    ]
  end

  @doc """
  Lists all known notifier modules across all contexts.

  ## Examples

      iex> Jarga.InfrastructureLayer.notifiers()
      [Jarga.Accounts.Infrastructure.Notifiers.UserNotifier, ...]
  """
  @spec notifiers() :: [module()]
  def notifiers do
    [
      # Accounts
      Jarga.Accounts.Infrastructure.Notifiers.UserNotifier,
      # Agents
      Jarga.Agents.Infrastructure.Notifiers.PubSubNotifier,
      # Documents
      Jarga.Documents.Infrastructure.Notifiers.PubSubNotifier,
      # Notifications
      Jarga.Notifications.Infrastructure.Notifiers.PubSubNotifier,
      # Projects
      Jarga.Projects.Infrastructure.Notifiers.EmailAndPubSubNotifier,
      # Workspaces
      Jarga.Workspaces.Infrastructure.Notifiers.WorkspaceNotifier,
      Jarga.Workspaces.Infrastructure.Notifiers.EmailAndPubSubNotifier,
      Jarga.Workspaces.Infrastructure.Notifiers.PubSubNotifier
    ]
  end

  @doc """
  Lists all known external service modules across all contexts.

  ## Examples

      iex> Jarga.InfrastructureLayer.external_services()
      [Jarga.Agents.Infrastructure.Services.LlmClient, ...]
  """
  @spec external_services() :: [module()]
  def external_services do
    [
      # Accounts
      Jarga.Accounts.Infrastructure.Services.TokenGenerator,
      # Agents
      Jarga.Agents.Infrastructure.Services.LlmClient
    ]
  end

  @doc """
  Returns a count summary of infrastructure layer modules.

  ## Examples

      iex> Jarga.InfrastructureLayer.summary()
      %{repositories: 16, schemas: 14, queries: 8, notifiers: 8, services: 2, total: 48}
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
