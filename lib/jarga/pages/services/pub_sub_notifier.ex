defmodule Jarga.Pages.Services.PubSubNotifier do
  @moduledoc """
  Default notification service implementation for pages.

  Uses Phoenix PubSub to broadcast real-time notifications to workspace members
  and to the page channel itself.
  """

  @behaviour Jarga.Pages.Services.NotificationService

  alias Jarga.Pages.Page

  @impl true
  def notify_page_visibility_changed(%Page{} = page) do
    # Broadcast to workspace for list updates
    Phoenix.PubSub.broadcast(
      Jarga.PubSub,
      "workspace:#{page.workspace_id}",
      {:page_visibility_changed, page.id, page.is_public}
    )

    # Also broadcast to the page itself for page show view
    Phoenix.PubSub.broadcast(
      Jarga.PubSub,
      "page:#{page.id}",
      {:page_visibility_changed, page.id, page.is_public}
    )

    :ok
  end

  @impl true
  def notify_page_pinned_changed(%Page{} = page) do
    # Broadcast to workspace for list updates
    Phoenix.PubSub.broadcast(
      Jarga.PubSub,
      "workspace:#{page.workspace_id}",
      {:page_pinned_changed, page.id, page.is_pinned}
    )

    # Also broadcast to the page itself for page show view
    Phoenix.PubSub.broadcast(
      Jarga.PubSub,
      "page:#{page.id}",
      {:page_pinned_changed, page.id, page.is_pinned}
    )

    :ok
  end

  @impl true
  def notify_page_title_changed(%Page{} = page) do
    # Broadcast to workspace for list updates
    Phoenix.PubSub.broadcast(
      Jarga.PubSub,
      "workspace:#{page.workspace_id}",
      {:page_title_changed, page.id, page.title}
    )

    # Also broadcast to the page itself for page show view
    Phoenix.PubSub.broadcast(
      Jarga.PubSub,
      "page:#{page.id}",
      {:page_title_changed, page.id, page.title}
    )

    :ok
  end
end
