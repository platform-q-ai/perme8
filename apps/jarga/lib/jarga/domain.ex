defmodule Jarga.Domain do
  @moduledoc """
  Domain layer namespace for the Jarga application.

  Jarga uses a **Bounded Context** architecture where each context
  (Agents, Chat, Documents, Notifications, Projects, Workspaces)
  has its own domain, application, and infrastructure layers.

  Note: User identity and authentication is handled by the separate `Identity` app.
  See `Identity.Domain` for user entities and policies.

  This module provides documentation and introspection for all domain layer
  modules across Jarga contexts.

  ## Domain Layer Principles

  The domain layer is the innermost layer and has NO external dependencies.
  It contains only:

  - **Entities** - Core business objects (pure data structures)
  - **Policies** - Business rules and invariants
  - **Domain Services** - Pure functions for domain logic
  - **Value Objects** - Immutable values with equality semantics

  ## Bounded Contexts

  Each context has its own domain layer:

  ### Identity (separate app - `Identity.Domain`)
  - Entities: User, ApiKey, UserToken
  - Policies: AuthenticationPolicy, TokenPolicy, ApiKeyPolicy
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

  ### Workspaces (migrated to `Identity.Domain`)
  - Entities: Workspace, WorkspaceMember → `Identity.Domain.Entities`
  - Services: SlugGenerator → `Identity.Domain.Services`

  ## Dependency Rules

  Domain modules MUST NOT depend on:
  - Application layer (use cases, application services)
  - Infrastructure layer (repositories, schemas, external services)
  - External libraries (Ecto, Phoenix, etc.)

  Domain modules MAY depend on:
  - Elixir/Erlang standard library
  - Other domain modules within the same context
  """

  use Boundary,
    top_level?: true,
    deps: [],
    exports: [
      Policies.DomainPermissionsPolicy
    ]

  @doc """
  Lists all known domain entity modules across all Jarga contexts.

  Note: User entities are in the Identity app. See `Identity.Domain.Entities.User`.

  ## Examples

      iex> Jarga.Domain.entities()
      [Jarga.Agents.Domain.Entities.Agent, ...]
  """
  @spec entities() :: [module()]
  def entities do
    [
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
      Jarga.Projects.Domain.Entities.Project
      # Workspaces — migrated to Identity app
    ]
  end

  @doc """
  Lists all known domain policy modules across all Jarga contexts.

  Note: Authentication policies are in the Identity app.

  ## Examples

      iex> Jarga.Domain.policies()
      [Jarga.Documents.Domain.Policies.DocumentAccessPolicy, ...]
  """
  @spec policies() :: [module()]
  def policies do
    [
      # Documents
      Jarga.Documents.Domain.Policies.DocumentAccessPolicy
    ]
  end

  @doc """
  Lists all known domain service modules across all Jarga contexts.

  ## Examples

      iex> Jarga.Domain.services()
      [Jarga.Agents.Domain.AgentCloner, ...]
  """
  @spec services() :: [module()]
  def services do
    [
      # Agents
      Jarga.Agents.Domain.AgentCloner,
      # Documents
      Jarga.Documents.Domain.SlugGenerator,
      Jarga.Documents.Domain.AgentQueryParser,
      # Projects
      Jarga.Projects.Domain.SlugGenerator
      # Workspaces — migrated to Identity app
    ]
  end

  @doc """
  Returns a map of all domain modules grouped by context.

  Note: Identity context (users, auth) is in a separate app.

  ## Examples

      iex> Jarga.Domain.by_context()
      %{
        agents: %{entities: [...], policies: [...], services: [...]},
        ...
      }
  """
  @spec by_context() :: map()
  def by_context do
    %{
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
      }
      # Workspaces — migrated to Identity app
      # See Identity.Domain for workspace entities and services
    }
  end
end
