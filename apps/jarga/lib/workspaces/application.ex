defmodule Jarga.Workspaces.Application do
  @moduledoc """
  Application layer boundary for the Workspaces context.

  Contains orchestration logic that coordinates domain and infrastructure:

  ## Use Cases
  - `UseCases.InviteMember` - Member invitation flow
  - `UseCases.ChangeMemberRole` - Member role change flow
  - `UseCases.RemoveMember` - Member removal flow
  - `UseCases.CreateNotificationsForPendingInvitations` - Create notifications for pending invites
  - `UseCases.UseCase` - Base use case behaviour

  ## Policies
  - `Policies.MembershipPolicy` - Membership rules
  - `Policies.PermissionsPolicy` - Permission rules

  ## Services
  - `Services.NotificationService` - Workspace notification service

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
      Jarga.Workspaces.Domain,
      # Cross-context dependencies (context + domain layer for entity access)
      Jarga.Accounts,
      Jarga.Accounts.Domain
    ],
    exports: [
      UseCases.InviteMember,
      UseCases.ChangeMemberRole,
      UseCases.RemoveMember,
      UseCases.CreateNotificationsForPendingInvitations,
      UseCases.UseCase,
      Policies.MembershipPolicy,
      Policies.PermissionsPolicy,
      Services.NotificationService,
      # Behaviours (interfaces for Infrastructure to implement)
      Behaviours.MembershipRepositoryBehaviour,
      Behaviours.NotificationServiceBehaviour,
      Behaviours.PubSubNotifierBehaviour,
      Behaviours.QueriesBehaviour
    ]
end
