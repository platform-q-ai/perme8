defmodule Jarga.Notifications.Infrastructure.Notifiers.PubSubNotifier do
  @moduledoc """
  No-op PubSub notification service for notification-related events.

  Legacy PubSub broadcasts have been removed. The EventBus now handles all
  structured event delivery via use case `event_bus.emit` calls. This module
  is retained as a no-op shell because use cases still inject it via
  `opts[:pubsub_notifier]`. Full removal of the notifier module, behaviour,
  and injection is deferred to Part 2c.
  """

  @behaviour Jarga.Notifications.Application.Behaviours.PubSubNotifierBehaviour

  @impl true
  def broadcast_invitation_created(
        _user_id,
        _workspace_id,
        _workspace_name,
        _invited_by_name,
        _role
      ),
      do: :ok

  @impl true
  def broadcast_workspace_joined(_user_id, _workspace_id), do: :ok

  @impl true
  def broadcast_invitation_declined(_user_id, _workspace_id), do: :ok

  @impl true
  def broadcast_new_notification(_user_id, _notification), do: :ok
end
