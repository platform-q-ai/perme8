defmodule Jarga.Projects.Services.EmailAndPubSubNotifier do
  @moduledoc """
  Default notification service implementation for projects.

  Uses Phoenix PubSub to broadcast real-time notifications to workspace members.
  """

  @behaviour Jarga.Projects.Services.NotificationService

  alias Jarga.Projects.Project

  @impl true
  def notify_project_created(%Project{} = project) do
    # Broadcast in-app notification via PubSub
    Phoenix.PubSub.broadcast(
      Jarga.PubSub,
      "workspace:#{project.workspace_id}",
      {:project_added, project.id}
    )

    :ok
  end

  @impl true
  def notify_project_deleted(%Project{} = project, workspace_id) do
    # Broadcast in-app notification via PubSub
    Phoenix.PubSub.broadcast(
      Jarga.PubSub,
      "workspace:#{workspace_id}",
      {:project_removed, project.id}
    )

    :ok
  end

  @impl true
  def notify_project_updated(%Project{} = project) do
    # Broadcast in-app notification via PubSub
    Phoenix.PubSub.broadcast(
      Jarga.PubSub,
      "workspace:#{project.workspace_id}",
      {:project_updated, project.id, project.name}
    )

    :ok
  end
end
