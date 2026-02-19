defmodule Agents.Infrastructure.Notifiers.PubSubNotifier do
  @moduledoc """
  No-op PubSub notification service for agents.

  Legacy PubSub broadcasts have been removed. The EventBus now handles all
  structured event delivery via use case `event_bus.emit` calls. This module
  is retained as a no-op shell because use cases still inject it via
  `opts[:pubsub_notifier]`. Full removal of the notifier module, behaviour,
  and injection is deferred to Part 2c.
  """

  @behaviour Agents.Application.Behaviours.PubSubNotifierBehaviour

  @impl true
  def notify_agent_updated(%{id: _, user_id: _}, _workspace_ids), do: :ok

  @impl true
  def notify_workspace_associations_changed(_agent, _added_workspace_ids, _removed_workspace_ids),
    do: :ok

  @impl true
  def notify_agent_deleted(_agent, _workspace_ids), do: :ok
end
