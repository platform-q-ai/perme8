defmodule Jarga.ApplicationLayer do
  @moduledoc """
  Application layer namespace for the Jarga application.

  Jarga uses a **Bounded Context** architecture where each context
  has its own application layer with use cases, policies, and services.

  This module provides documentation and introspection for all application layer
  modules across contexts.

  ## Application Layer Principles

  The application layer orchestrates business operations by:

  - Coordinating domain entities and policies
  - Defining the public API for each context
  - Implementing use cases (single-responsibility operations)
  - Depending on abstractions (behaviours) for infrastructure

  ## Use Case Pattern

  All use cases in Jarga follow a consistent pattern:

  ```elixir
  defmodule MyContext.Application.UseCases.DoSomething do
    def execute(params, opts \\\\ []) do
      # 1. Validate input
      # 2. Apply domain policies
      # 3. Coordinate with repositories (via injection)
      # 4. Return {:ok, result} or {:error, reason}
    end
  end
  ```

  ## Dependency Rules

  Application layer modules:
  - MUST depend only on domain layer entities and policies
  - MUST use dependency injection for infrastructure concerns
  - MUST NOT directly call Repo, File, or external services
  - MAY define behaviours for infrastructure implementations
  """

  @doc """
  Lists all known use case modules across all contexts.

  ## Examples

      iex> Jarga.ApplicationLayer.use_cases()
      [Jarga.Agents.Application.UseCases.CreateUserAgent, ...]
  """
  @spec use_cases() :: [module()]
  def use_cases do
    [
      # Note: Account use cases (registration, authentication, session, API keys)
      # have been moved to the Identity app. API-specific use cases have been
      # moved to the JargaApi app.
      #
      # Agents
      Jarga.Agents.Application.UseCases.CreateUserAgent,
      Jarga.Agents.Application.UseCases.UpdateUserAgent,
      Jarga.Agents.Application.UseCases.DeleteUserAgent,
      Jarga.Agents.Application.UseCases.ListUserAgents,
      Jarga.Agents.Application.UseCases.ListViewableAgents,
      Jarga.Agents.Application.UseCases.ListWorkspaceAvailableAgents,
      Jarga.Agents.Application.UseCases.CloneSharedAgent,
      Jarga.Agents.Application.UseCases.AddAgentToWorkspace,
      Jarga.Agents.Application.UseCases.RemoveAgentFromWorkspace,
      Jarga.Agents.Application.UseCases.SyncAgentWorkspaces,
      Jarga.Agents.Application.UseCases.ValidateAgentParams,
      Jarga.Agents.Application.UseCases.AgentQuery,
      # Chat
      Jarga.Chat.Application.UseCases.CreateSession,
      Jarga.Chat.Application.UseCases.LoadSession,
      Jarga.Chat.Application.UseCases.ListSessions,
      Jarga.Chat.Application.UseCases.DeleteSession,
      Jarga.Chat.Application.UseCases.SaveMessage,
      Jarga.Chat.Application.UseCases.DeleteMessage,
      Jarga.Chat.Application.UseCases.PrepareContext,
      # Documents
      Jarga.Documents.Application.UseCases.CreateDocument,
      Jarga.Documents.Application.UseCases.UpdateDocument,
      Jarga.Documents.Application.UseCases.DeleteDocument,
      Jarga.Documents.Application.UseCases.ExecuteAgentQuery,
      # Notifications
      Jarga.Notifications.Application.UseCases.ListNotifications,
      Jarga.Notifications.Application.UseCases.ListUnreadNotifications,
      Jarga.Notifications.Application.UseCases.GetUnreadCount,
      Jarga.Notifications.Application.UseCases.MarkAsRead,
      Jarga.Notifications.Application.UseCases.MarkAllAsRead,
      Jarga.Notifications.Application.UseCases.CreateWorkspaceInvitationNotification,
      Jarga.Notifications.Application.UseCases.AcceptWorkspaceInvitation,
      Jarga.Notifications.Application.UseCases.DeclineWorkspaceInvitation,
      # Projects
      Jarga.Projects.Application.UseCases.CreateProject,
      Jarga.Projects.Application.UseCases.UpdateProject,
      Jarga.Projects.Application.UseCases.DeleteProject,
      # Workspaces
      Jarga.Workspaces.Application.UseCases.InviteMember,
      Jarga.Workspaces.Application.UseCases.RemoveMember,
      Jarga.Workspaces.Application.UseCases.ChangeMemberRole,
      Jarga.Workspaces.Application.UseCases.CreateNotificationsForPendingInvitations
    ]
  end

  @doc """
  Lists all known application policy modules across all contexts.

  These are policies in the application layer (not domain policies).

  ## Examples

      iex> Jarga.ApplicationLayer.policies()
      [Jarga.Agents.Application.Policies.AgentPolicy, ...]
  """
  @spec policies() :: [module()]
  def policies do
    [
      # Agents
      Jarga.Agents.Application.Policies.AgentPolicy,
      Jarga.Agents.Application.Policies.VisibilityPolicy,
      # Documents
      Jarga.Documents.Application.Policies.DocumentAuthorizationPolicy,
      # Workspaces
      Jarga.Workspaces.Application.Policies.MembershipPolicy,
      Jarga.Workspaces.Application.Policies.PermissionsPolicy
    ]
  end

  @doc """
  Lists all known application service modules across all contexts.

  ## Examples

      iex> Jarga.ApplicationLayer.services()
      [Jarga.Documents.Application.Services.NotificationService, ...]
  """
  @spec services() :: [module()]
  def services do
    [
      # Note: Account services (PasswordService, ApiKeyTokenService) have been
      # moved to the Identity app.
      #
      # Documents
      Jarga.Documents.Application.Services.NotificationService,
      # Projects
      Jarga.Projects.Application.Services.NotificationService,
      # Workspaces
      Jarga.Workspaces.Application.Services.NotificationService
    ]
  end

  @doc """
  Returns a count summary of application layer modules.

  ## Examples

      iex> Jarga.ApplicationLayer.summary()
      %{use_cases: 42, policies: 5, services: 6, total: 53}
  """
  @spec summary() :: map()
  def summary do
    use_case_count = length(use_cases())
    policy_count = length(policies())
    service_count = length(services())

    %{
      use_cases: use_case_count,
      policies: policy_count,
      services: service_count,
      total: use_case_count + policy_count + service_count
    }
  end
end
