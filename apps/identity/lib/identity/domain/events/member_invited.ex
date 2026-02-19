defmodule Identity.Domain.Events.MemberInvited do
  @moduledoc """
  Domain event emitted when a member is invited to a workspace.

  Emitted by `InviteMember` and `CreateNotificationsForPendingInvitations`
  use cases after the invitation is created.
  """

  use Perme8.Events.DomainEvent,
    aggregate_type: "workspace_member",
    fields: [
      user_id: nil,
      workspace_name: nil,
      invited_by_name: nil,
      role: nil
    ],
    required: [:user_id, :workspace_id, :workspace_name, :invited_by_name, :role]
end
