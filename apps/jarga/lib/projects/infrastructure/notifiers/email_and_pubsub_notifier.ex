defmodule Jarga.Projects.Infrastructure.Notifiers.EmailAndPubSubNotifier do
  @moduledoc """
  No-op notification service for projects.

  Legacy PubSub broadcasts have been removed. The EventBus now handles all
  structured event delivery via use case `event_bus.emit` calls. This module
  is retained as a no-op shell because use cases still inject it via
  `opts[:notifier]`. Full removal of the notifier module, behaviour, and
  injection is deferred to Part 2c.
  """

  @behaviour Jarga.Projects.Application.Behaviours.NotificationServiceBehaviour

  alias Jarga.Projects.Domain.Entities.Project

  @impl true
  def notify_project_created(%Project{}), do: :ok

  @impl true
  def notify_project_deleted(%Project{}, _workspace_id), do: :ok

  @impl true
  def notify_project_updated(%Project{}), do: :ok
end
