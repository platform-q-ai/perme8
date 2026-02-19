defmodule Perme8.Events.EventTypeUniquenessTest do
  use ExUnit.Case, async: true

  @moduledoc """
  Cross-cutting test that verifies all 31 domain event types are unique.
  This prevents naming collisions as new events are added.
  """

  @all_event_modules [
    # Identity (4)
    Identity.Domain.Events.MemberInvited,
    Identity.Domain.Events.WorkspaceUpdated,
    Identity.Domain.Events.MemberRemoved,
    Identity.Domain.Events.WorkspaceInvitationNotified,
    # Projects (4)
    Jarga.Projects.Domain.Events.ProjectCreated,
    Jarga.Projects.Domain.Events.ProjectUpdated,
    Jarga.Projects.Domain.Events.ProjectDeleted,
    Jarga.Projects.Domain.Events.ProjectArchived,
    # Documents (5)
    Jarga.Documents.Domain.Events.DocumentCreated,
    Jarga.Documents.Domain.Events.DocumentDeleted,
    Jarga.Documents.Domain.Events.DocumentTitleChanged,
    Jarga.Documents.Domain.Events.DocumentVisibilityChanged,
    Jarga.Documents.Domain.Events.DocumentPinnedChanged,
    # Agents (5)
    Agents.Domain.Events.AgentCreated,
    Agents.Domain.Events.AgentUpdated,
    Agents.Domain.Events.AgentDeleted,
    Agents.Domain.Events.AgentAddedToWorkspace,
    Agents.Domain.Events.AgentRemovedFromWorkspace,
    # Chat (3)
    Jarga.Chat.Domain.Events.ChatSessionStarted,
    Jarga.Chat.Domain.Events.ChatMessageSent,
    Jarga.Chat.Domain.Events.ChatSessionDeleted,
    # Notifications (3)
    Jarga.Notifications.Domain.Events.NotificationCreated,
    Jarga.Notifications.Domain.Events.NotificationRead,
    Jarga.Notifications.Domain.Events.NotificationActionTaken,
    # ERM (7)
    EntityRelationshipManager.Domain.Events.SchemaCreated,
    EntityRelationshipManager.Domain.Events.SchemaUpdated,
    EntityRelationshipManager.Domain.Events.EntityCreated,
    EntityRelationshipManager.Domain.Events.EntityUpdated,
    EntityRelationshipManager.Domain.Events.EntityDeleted,
    EntityRelationshipManager.Domain.Events.EdgeCreated,
    EntityRelationshipManager.Domain.Events.EdgeDeleted
  ]

  describe "event_type uniqueness" do
    test "all 31 event modules are listed" do
      assert length(@all_event_modules) == 31
    end

    test "all event_type/0 strings are unique" do
      event_types = Enum.map(@all_event_modules, & &1.event_type())

      unique_types = Enum.uniq(event_types)

      assert length(event_types) == length(unique_types),
             "Duplicate event types found: #{inspect(event_types -- unique_types)}"
    end

    test "all event_type/0 strings follow context.event_name format" do
      for module <- @all_event_modules do
        event_type = module.event_type()

        assert String.contains?(event_type, "."),
               "Event type #{event_type} for #{inspect(module)} does not contain a dot"

        [context, event_name] = String.split(event_type, ".", parts: 2)
        assert context != "", "Empty context in event type for #{inspect(module)}"
        assert event_name != "", "Empty event name in event type for #{inspect(module)}"
      end
    end
  end
end
