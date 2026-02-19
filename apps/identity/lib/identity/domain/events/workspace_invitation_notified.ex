defmodule Identity.Domain.Events.WorkspaceInvitationNotified do
  @moduledoc """
  Domain event emitted when an existing user is notified of a workspace invitation.

  Emitted by `Identity.Infrastructure.Notifiers.EmailAndPubSubNotifier.notify_existing_user/3`.
  The `target_user_id` is the invitee. This enables user-scoped topic derivation.
  """

  use Perme8.Events.DomainEvent,
    aggregate_type: "workspace_member",
    fields: [target_user_id: nil, workspace_name: nil, invited_by_name: nil, role: nil],
    required: [:workspace_id, :target_user_id, :workspace_name, :invited_by_name]
end
