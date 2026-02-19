defmodule Identity.Domain.Events.MemberRemoved do
  @moduledoc """
  Domain event emitted when a member is removed from a workspace.

  Emitted by `Identity.Application.UseCases.RemoveMember` when a joined member is removed.
  The `target_user_id` field is the user who was removed. The `actor_id` is whoever performed the removal.
  """

  use Perme8.Events.DomainEvent,
    aggregate_type: "workspace_member",
    fields: [target_user_id: nil],
    required: [:workspace_id, :target_user_id]
end
