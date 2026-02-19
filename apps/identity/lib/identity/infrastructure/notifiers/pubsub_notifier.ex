defmodule Identity.Infrastructure.Notifiers.PubSubNotifier do
  @moduledoc """
  No-op PubSub notifier for workspace invitation events.

  Legacy PubSub broadcasts have been removed. The EventBus now handles all
  structured event delivery. This module is retained as a no-op shell because
  use cases still inject it via `opts[:pubsub_notifier]`. Full removal of the
  notifier module, behaviour, and injection is deferred to Part 2c.
  """

  @behaviour Identity.Application.Behaviours.PubSubNotifierBehaviour

  @impl true
  def broadcast_invitation_created(
        _user_id,
        _workspace_id,
        _workspace_name,
        _invited_by_name,
        _role
      ) do
    # No-op: EventBus.emit handles all event delivery now
    :ok
  end
end
