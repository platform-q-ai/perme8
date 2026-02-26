defmodule Identity.Domain.Events.MemberJoined do
  @moduledoc """
  Domain event emitted when a member accepts a workspace invitation and joins.

  Emitted by `Identity.accept_invitation_by_workspace/2` after the invitation
  is accepted (user_id and joined_at are set on the workspace_member record).

  The `target_user_id` field is the user who joined. This enables user-scoped
  topic derivation so LiveViews subscribed to the user's event topic can
  reload their workspace lists.
  """

  use Perme8.Events.DomainEvent,
    aggregate_type: "workspace_member",
    fields: [target_user_id: nil],
    required: [:workspace_id, :target_user_id]
end
