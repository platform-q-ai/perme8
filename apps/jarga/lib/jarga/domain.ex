defmodule Jarga.Domain do
  @moduledoc """
  Domain layer namespace for the Jarga application.

  Jarga uses a **Bounded Context** architecture where each context
  (Accounts, Agents, Chat, Documents, Notifications, Projects, Workspaces)
  has its own domain, application, and infrastructure layers.

  This module provides documentation and introspection for all domain layer
  modules across contexts.

  ## Domain Layer Principles

  The domain layer is the innermost layer and has NO external dependencies.
  It contains only:

  - **Entities** - Core business objects (pure data structures)
  - **Policies** - Business rules and invariants
  - **Domain Services** - Pure functions for domain logic
  - **Value Objects** - Immutable values with equality semantics

  ## Bounded Contexts

  Each context has its own domain layer:

  ### Accounts (`Jarga.Accounts.Domain`)
  - Entities: User, ApiKey, UserToken
  - Policies: AuthenticationPolicy, TokenPolicy, ApiKeyPolicy, WorkspaceAccessPolicy
  - Services: TokenBuilder

  ### Agents (`Jarga.Agents.Domain`)
  - Entities: Agent, WorkspaceAgentJoin
  - Services: AgentCloner

  ### Chat (`Jarga.Chat.Domain`)
  - Entities: Session, Message

  ### Documents (`Jarga.Documents.Domain`)
  - Entities: Document, DocumentComponent
  - Policies: DocumentAccessPolicy
  - Services: SlugGenerator, AgentQueryParser

  ### Projects (`Jarga.Projects.Domain`)
  - Entities: Project
  - Services: SlugGenerator

  ### Workspaces (`Jarga.Workspaces.Domain`)
  - Entities: Workspace, WorkspaceMember
  - Services: SlugGenerator

  ## Dependency Rules

  Domain modules MUST NOT depend on:
  - Application layer (use cases, application services)
  - Infrastructure layer (repositories, schemas, external services)
  - External libraries (Ecto, Phoenix, etc.)

  Domain modules MAY depend on:
  - Elixir/Erlang standard library
  - Other domain modules within the same context
  """

  @doc """
  Lists all known domain entity modules across all contexts.

  ## Examples

      iex> Jarga.Domain.entities()
      [Jarga.Accounts.Domain.Entities.User, ...]
  """
  @spec entities() :: [module()]
  def entities do
    [
      # Accounts
      Jarga.Accounts.Domain.Entities.User,
      Jarga.Accounts.Domain.Entities.ApiKey,
      Jarga.Accounts.Domain.Entities.UserToken,
      # Agents
      Jarga.Agents.Domain.Entities.Agent,
      Jarga.Agents.Domain.Entities.WorkspaceAgentJoin,
      # Chat
      Jarga.Chat.Domain.Entities.Session,
      Jarga.Chat.Domain.Entities.Message,
      # Documents
      Jarga.Documents.Domain.Entities.Document,
      Jarga.Documents.Domain.Entities.DocumentComponent,
      Jarga.Documents.Notes.Domain.Entities.Note,
      # Projects
      Jarga.Projects.Domain.Entities.Project,
      # Workspaces
      Jarga.Workspaces.Domain.Entities.Workspace,
      Jarga.Workspaces.Domain.Entities.WorkspaceMember
    ]
  end

  @doc """
  Lists all known domain policy modules across all contexts.

  ## Examples

      iex> Jarga.Domain.policies()
      [Jarga.Accounts.Domain.Policies.AuthenticationPolicy, ...]
  """
  @spec policies() :: [module()]
  def policies do
    [
      # Accounts
      Jarga.Accounts.Domain.Policies.AuthenticationPolicy,
      Jarga.Accounts.Domain.Policies.TokenPolicy,
      Jarga.Accounts.Domain.Policies.ApiKeyPolicy,
      Jarga.Accounts.Domain.Policies.WorkspaceAccessPolicy,
      # Documents
      Jarga.Documents.Domain.Policies.DocumentAccessPolicy
    ]
  end

  @doc """
  Lists all known domain service modules across all contexts.

  ## Examples

      iex> Jarga.Domain.services()
      [Jarga.Accounts.Domain.Services.TokenBuilder, ...]
  """
  @spec services() :: [module()]
  def services do
    [
      # Accounts
      Jarga.Accounts.Domain.Services.TokenBuilder,
      # Agents
      Jarga.Agents.Domain.AgentCloner,
      # Documents
      Jarga.Documents.Domain.SlugGenerator,
      Jarga.Documents.Domain.AgentQueryParser,
      # Projects
      Jarga.Projects.Domain.SlugGenerator,
      # Workspaces
      Jarga.Workspaces.Domain.SlugGenerator
    ]
  end

  @doc """
  Returns a map of all domain modules grouped by context.

  ## Examples

      iex> Jarga.Domain.by_context()
      %{
        accounts: %{entities: [...], policies: [...], services: [...]},
        ...
      }
  """
  @spec by_context() :: map()
  def by_context do
    %{
      accounts: %{
        entities: [
          Jarga.Accounts.Domain.Entities.User,
          Jarga.Accounts.Domain.Entities.ApiKey,
          Jarga.Accounts.Domain.Entities.UserToken
        ],
        policies: [
          Jarga.Accounts.Domain.Policies.AuthenticationPolicy,
          Jarga.Accounts.Domain.Policies.TokenPolicy,
          Jarga.Accounts.Domain.Policies.ApiKeyPolicy,
          Jarga.Accounts.Domain.Policies.WorkspaceAccessPolicy
        ],
        services: [Jarga.Accounts.Domain.Services.TokenBuilder]
      },
      agents: %{
        entities: [
          Jarga.Agents.Domain.Entities.Agent,
          Jarga.Agents.Domain.Entities.WorkspaceAgentJoin
        ],
        policies: [],
        services: [Jarga.Agents.Domain.AgentCloner]
      },
      chat: %{
        entities: [
          Jarga.Chat.Domain.Entities.Session,
          Jarga.Chat.Domain.Entities.Message
        ],
        policies: [],
        services: []
      },
      documents: %{
        entities: [
          Jarga.Documents.Domain.Entities.Document,
          Jarga.Documents.Domain.Entities.DocumentComponent,
          Jarga.Documents.Notes.Domain.Entities.Note
        ],
        policies: [Jarga.Documents.Domain.Policies.DocumentAccessPolicy],
        services: [
          Jarga.Documents.Domain.SlugGenerator,
          Jarga.Documents.Domain.AgentQueryParser
        ]
      },
      projects: %{
        entities: [Jarga.Projects.Domain.Entities.Project],
        policies: [],
        services: [Jarga.Projects.Domain.SlugGenerator]
      },
      workspaces: %{
        entities: [
          Jarga.Workspaces.Domain.Entities.Workspace,
          Jarga.Workspaces.Domain.Entities.WorkspaceMember
        ],
        policies: [],
        services: [Jarga.Workspaces.Domain.SlugGenerator]
      }
    }
  end
end
