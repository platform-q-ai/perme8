defmodule Jarga.Documents.Infrastructure.Notifiers.PubSubNotifier do
  @moduledoc """
  Default notification service implementation for documents.

  Uses Phoenix PubSub to broadcast real-time notifications to workspace members
  and to the document channel itself.
  """

  @behaviour Jarga.Documents.Application.Services.NotificationService

  alias Jarga.Documents.Domain.Entities.Document

  @impl true
  def notify_document_visibility_changed(%Document{} = document) do
    # Broadcast to workspace for list updates
    Phoenix.PubSub.broadcast(
      Jarga.PubSub,
      "workspace:#{document.workspace_id}",
      {:document_visibility_changed, document.id, document.is_public}
    )

    # Also broadcast to the document itself for document show view
    Phoenix.PubSub.broadcast(
      Jarga.PubSub,
      "document:#{document.id}",
      {:document_visibility_changed, document.id, document.is_public}
    )

    :ok
  end

  @impl true
  def notify_document_pinned_changed(%Document{} = document) do
    # Broadcast to workspace for list updates
    Phoenix.PubSub.broadcast(
      Jarga.PubSub,
      "workspace:#{document.workspace_id}",
      {:document_pinned_changed, document.id, document.is_pinned}
    )

    # Also broadcast to the document itself for document show view
    Phoenix.PubSub.broadcast(
      Jarga.PubSub,
      "document:#{document.id}",
      {:document_pinned_changed, document.id, document.is_pinned}
    )

    :ok
  end

  @impl true
  def notify_document_title_changed(%Document{} = document) do
    # Broadcast to workspace for list updates
    Phoenix.PubSub.broadcast(
      Jarga.PubSub,
      "workspace:#{document.workspace_id}",
      {:document_title_changed, document.id, document.title}
    )

    # Also broadcast to the document itself for document show view
    Phoenix.PubSub.broadcast(
      Jarga.PubSub,
      "document:#{document.id}",
      {:document_title_changed, document.id, document.title}
    )

    :ok
  end

  @impl true
  def notify_document_created(%Document{} = document) do
    # Broadcast to workspace for list updates
    Phoenix.PubSub.broadcast(
      Jarga.PubSub,
      "workspace:#{document.workspace_id}",
      {:document_created, document}
    )

    :ok
  end

  @impl true
  def notify_document_deleted(%Document{} = document) do
    # Broadcast to workspace for list updates
    Phoenix.PubSub.broadcast(
      Jarga.PubSub,
      "workspace:#{document.workspace_id}",
      {:document_deleted, document.id}
    )

    :ok
  end
end
