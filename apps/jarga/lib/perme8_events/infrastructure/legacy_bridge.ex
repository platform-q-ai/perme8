defmodule Perme8.Events.Infrastructure.LegacyBridge do
  @moduledoc """
  Translates structured domain events into legacy PubSub tuple format.

  This bridge ensures backward compatibility during the migration from
  ad-hoc PubSub notifications to structured domain events. It will be
  removed once all consumers have migrated to the new event format.

  ## How It Works

  1. `EventBus.emit/2` calls `broadcast_legacy/1` after broadcasting the structured event
  2. `broadcast_legacy/1` calls `translate/1` to get legacy topic/message pairs
  3. Each pair is broadcast via Phoenix.PubSub on the legacy topic

  ## Legacy Data

  For events that need to pass complex data (agent structs, document structs,
  notification structs), the use case populates `event.metadata.legacy_data`
  with the data needed for backward compatibility.
  """

  @pubsub Jarga.PubSub

  @doc """
  Translates a domain event into a list of `{topic, message}` tuples
  for legacy PubSub broadcasting.

  Returns `[]` for events that have no legacy representation (Chat, ERM events).
  """

  # --- Projects Context ---

  def translate(%Jarga.Projects.Domain.Events.ProjectCreated{} = event) do
    [{"workspace:#{event.workspace_id}", {:project_added, event.project_id}}]
  end

  def translate(%Jarga.Projects.Domain.Events.ProjectUpdated{} = event) do
    [{"workspace:#{event.workspace_id}", {:project_updated, event.project_id, event.name}}]
  end

  def translate(%Jarga.Projects.Domain.Events.ProjectDeleted{} = event) do
    [{"workspace:#{event.workspace_id}", {:project_removed, event.project_id}}]
  end

  # --- Documents Context ---

  def translate(%Jarga.Documents.Domain.Events.DocumentCreated{} = event) do
    legacy_data = get_in(event.metadata, [:legacy_data]) || %{}
    [{"workspace:#{event.workspace_id}", {:document_created, legacy_data}}]
  end

  def translate(%Jarga.Documents.Domain.Events.DocumentDeleted{} = event) do
    [{"workspace:#{event.workspace_id}", {:document_deleted, event.document_id}}]
  end

  def translate(%Jarga.Documents.Domain.Events.DocumentTitleChanged{} = event) do
    msg = {:document_title_changed, event.document_id, event.title}

    [
      {"workspace:#{event.workspace_id}", msg},
      {"document:#{event.document_id}", msg}
    ]
  end

  def translate(%Jarga.Documents.Domain.Events.DocumentVisibilityChanged{} = event) do
    msg = {:document_visibility_changed, event.document_id, event.is_public}

    [
      {"workspace:#{event.workspace_id}", msg},
      {"document:#{event.document_id}", msg}
    ]
  end

  def translate(%Jarga.Documents.Domain.Events.DocumentPinnedChanged{} = event) do
    msg = {:document_pinned_changed, event.document_id, event.is_pinned}

    [
      {"workspace:#{event.workspace_id}", msg},
      {"document:#{event.document_id}", msg}
    ]
  end

  # --- Agents Context ---

  def translate(%Agents.Domain.Events.AgentUpdated{} = event) do
    agent_data = get_in(event.metadata, [:legacy_data]) || %{}
    msg = {:workspace_agent_updated, agent_data}

    workspace_topics =
      Enum.map(event.workspace_ids, fn wid ->
        {"workspace:#{wid}", msg}
      end)

    workspace_topics ++ [{"user:#{event.user_id}", msg}]
  end

  def translate(%Agents.Domain.Events.AgentDeleted{} = event) do
    agent_data = get_in(event.metadata, [:legacy_data]) || %{}
    msg = {:workspace_agent_updated, agent_data}

    workspace_topics =
      Enum.map(event.workspace_ids, fn wid ->
        {"workspace:#{wid}", msg}
      end)

    workspace_topics ++ [{"user:#{event.user_id}", msg}]
  end

  def translate(%Agents.Domain.Events.AgentAddedToWorkspace{} = event) do
    agent_data = get_in(event.metadata, [:legacy_data]) || %{}
    msg = {:workspace_agent_updated, agent_data}

    [
      {"workspace:#{event.workspace_id}", msg},
      {"user:#{event.user_id}", msg}
    ]
  end

  def translate(%Agents.Domain.Events.AgentRemovedFromWorkspace{} = event) do
    agent_data = get_in(event.metadata, [:legacy_data]) || %{}
    msg = {:workspace_agent_updated, agent_data}

    [
      {"workspace:#{event.workspace_id}", msg},
      {"user:#{event.user_id}", msg}
    ]
  end

  # --- Notifications Context ---

  def translate(%Jarga.Notifications.Domain.Events.NotificationCreated{} = event) do
    notification_data = get_in(event.metadata, [:legacy_data]) || %{}
    [{"user:#{event.user_id}:notifications", {:new_notification, notification_data}}]
  end

  def translate(
        %Jarga.Notifications.Domain.Events.NotificationActionTaken{action: "accepted"} = event
      ) do
    [
      {"user:#{event.user_id}", {:workspace_joined, event.workspace_id}},
      {"workspace:#{event.workspace_id}", {:member_joined, event.user_id}}
    ]
  end

  def translate(
        %Jarga.Notifications.Domain.Events.NotificationActionTaken{action: "declined"} = event
      ) do
    [{"workspace:#{event.workspace_id}", {:invitation_declined, event.user_id}}]
  end

  # --- Identity Context ---

  def translate(%Identity.Domain.Events.MemberInvited{} = event) do
    [
      {"workspace_invitations",
       {:workspace_invitation_created,
        %{
          user_id: event.user_id,
          workspace_id: event.workspace_id,
          workspace_name: event.workspace_name,
          invited_by_name: event.invited_by_name,
          role: event.role
        }}}
    ]
  end

  def translate(%Identity.Domain.Events.WorkspaceUpdated{} = event) do
    [{"workspace:#{event.workspace_id}", {:workspace_updated, event.workspace_id, event.name}}]
  end

  def translate(%Identity.Domain.Events.MemberRemoved{} = event) do
    [{"user:#{event.target_user_id}", {:workspace_removed, event.workspace_id}}]
  end

  def translate(%Identity.Domain.Events.WorkspaceInvitationNotified{} = event) do
    [
      {"user:#{event.target_user_id}",
       {:workspace_invitation, event.workspace_id, event.workspace_name, event.invited_by_name}}
    ]
  end

  # --- Catch-all (Chat, ERM, and unknown events have no legacy translations) ---

  def translate(_event), do: []

  @doc """
  Broadcasts legacy tuple messages for a domain event.

  Calls `translate/1` and broadcasts each resulting `{topic, message}` pair
  on the legacy PubSub.
  """
  def broadcast_legacy(event) do
    event
    |> translate()
    |> Enum.each(fn {topic, message} ->
      Phoenix.PubSub.broadcast(@pubsub, topic, message)
    end)
  end
end
