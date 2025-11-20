defmodule Jarga.Agents.Infrastructure.Services.PubSubNotifier do
  @moduledoc """
  PubSub notification service for agents.

  Broadcasts real-time notifications to workspace members when agents are:
  - Added to or removed from workspaces
  - Updated (including visibility changes)
  - Deleted

  This ensures all users see accurate agent lists in real-time.
  """

  alias Jarga.Agents.Infrastructure.Agent

  @doc """
  Notifies all affected workspaces when an agent is updated.

  Broadcasts to:
  - All workspaces the agent is currently in
  - User's personal agent topic (for non-workspace pages)
  """
  def notify_agent_updated(%Agent{} = agent, workspace_ids) when is_list(workspace_ids) do
    # Broadcast to all workspaces that have this agent
    Enum.each(workspace_ids, fn workspace_id ->
      Phoenix.PubSub.broadcast(
        Jarga.PubSub,
        "workspace:#{workspace_id}",
        {:workspace_agent_updated, agent}
      )
    end)

    # Broadcast to user's topic for non-workspace pages (dashboard, agents index, etc.)
    Phoenix.PubSub.broadcast(
      Jarga.PubSub,
      "user:#{agent.user_id}",
      {:workspace_agent_updated, agent}
    )

    :ok
  end

  @doc """
  Notifies when agent workspace associations change.

  Broadcasts to:
  - Workspaces the agent was removed from (so they remove it from UI)
  - Workspaces the agent was added to (so they add it to UI)
  - User's personal agent topic
  """
  def notify_workspace_associations_changed(agent, added_workspace_ids, removed_workspace_ids) do
    # Notify workspaces agent was removed from
    Enum.each(removed_workspace_ids, fn workspace_id ->
      Phoenix.PubSub.broadcast(
        Jarga.PubSub,
        "workspace:#{workspace_id}",
        {:workspace_agent_updated, agent}
      )
    end)

    # Notify workspaces agent was added to
    Enum.each(added_workspace_ids, fn workspace_id ->
      Phoenix.PubSub.broadcast(
        Jarga.PubSub,
        "workspace:#{workspace_id}",
        {:workspace_agent_updated, agent}
      )
    end)

    # Notify user's topic
    Phoenix.PubSub.broadcast(
      Jarga.PubSub,
      "user:#{agent.user_id}",
      {:workspace_agent_updated, agent}
    )

    :ok
  end

  @doc """
  Notifies when an agent is deleted.

  Broadcasts to all workspaces that had this agent so they can remove it.
  """
  def notify_agent_deleted(agent, workspace_ids) do
    # Notify all workspaces that had this agent
    Enum.each(workspace_ids, fn workspace_id ->
      Phoenix.PubSub.broadcast(
        Jarga.PubSub,
        "workspace:#{workspace_id}",
        {:workspace_agent_updated, agent}
      )
    end)

    # Notify user's topic
    Phoenix.PubSub.broadcast(
      Jarga.PubSub,
      "user:#{agent.user_id}",
      {:workspace_agent_updated, agent}
    )

    :ok
  end
end
