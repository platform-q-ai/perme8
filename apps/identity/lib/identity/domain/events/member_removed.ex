defmodule Identity.Domain.Events.MemberRemoved do
  @moduledoc """
  Domain event emitted when a member is removed from a workspace.

  Emitted by `Identity.Infrastructure.Notifiers.EmailAndPubSubNotifier.notify_user_removed/2`.
  The `target_user_id` field is the user who was removed. The `actor_id` is whoever performed the removal.
  """

  use Perme8.Events.DomainEvent,
    aggregate_type: "workspace_member",
    fields: [target_user_id: nil],
    required: [:workspace_id, :target_user_id]
end
