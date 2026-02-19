defmodule Jarga.Documents.Infrastructure.Notifiers.PubSubNotifier do
  @moduledoc """
  No-op notification service for documents.

  Legacy PubSub broadcasts have been removed. The EventBus now handles all
  structured event delivery via use case `event_bus.emit` calls. This module
  is retained as a no-op shell because use cases still inject it via
  `opts[:notifier]`. Full removal of the notifier module, behaviour, and
  injection is deferred to Part 2c.
  """

  @behaviour Jarga.Documents.Application.Behaviours.NotificationServiceBehaviour

  alias Jarga.Documents.Domain.Entities.Document

  @impl true
  def notify_document_visibility_changed(%Document{}), do: :ok

  @impl true
  def notify_document_pinned_changed(%Document{}), do: :ok

  @impl true
  def notify_document_title_changed(%Document{}), do: :ok

  @impl true
  def notify_document_created(%Document{}), do: :ok

  @impl true
  def notify_document_deleted(%Document{}), do: :ok
end
