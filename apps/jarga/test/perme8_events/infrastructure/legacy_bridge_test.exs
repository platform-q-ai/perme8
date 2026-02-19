defmodule Perme8.Events.Infrastructure.LegacyBridgeTest do
  use ExUnit.Case, async: true

  alias Perme8.Events.Infrastructure.LegacyBridge

  # Aliases for all event types with legacy translations
  alias Jarga.Projects.Domain.Events.ProjectCreated
  alias Jarga.Projects.Domain.Events.ProjectUpdated
  alias Jarga.Projects.Domain.Events.ProjectDeleted

  alias Jarga.Documents.Domain.Events.DocumentCreated
  alias Jarga.Documents.Domain.Events.DocumentDeleted
  alias Jarga.Documents.Domain.Events.DocumentTitleChanged
  alias Jarga.Documents.Domain.Events.DocumentVisibilityChanged
  alias Jarga.Documents.Domain.Events.DocumentPinnedChanged

  alias Agents.Domain.Events.AgentUpdated
  alias Agents.Domain.Events.AgentDeleted
  alias Agents.Domain.Events.AgentAddedToWorkspace
  alias Agents.Domain.Events.AgentRemovedFromWorkspace

  alias Jarga.Notifications.Domain.Events.NotificationCreated
  alias Jarga.Notifications.Domain.Events.NotificationActionTaken

  alias Identity.Domain.Events.MemberInvited

  # Test event to verify catch-all behaviour
  defmodule UnknownEvent do
    use Perme8.Events.DomainEvent,
      aggregate_type: "unknown",
      fields: [data: nil],
      required: []
  end

  # --- Projects Context ---

  describe "translate/1 - Projects" do
    test "ProjectCreated translates to legacy project_added tuple" do
      event =
        ProjectCreated.new(%{
          aggregate_id: "proj-123",
          actor_id: "user-1",
          project_id: "proj-123",
          workspace_id: "ws-456",
          user_id: "user-1",
          name: "Test",
          slug: "test"
        })

      assert [{"workspace:ws-456", {:project_added, "proj-123"}}] =
               LegacyBridge.translate(event)
    end

    test "ProjectUpdated translates to legacy project_updated tuple" do
      event =
        ProjectUpdated.new(%{
          aggregate_id: "proj-123",
          actor_id: "user-1",
          project_id: "proj-123",
          workspace_id: "ws-456",
          user_id: "user-1",
          name: "New Name"
        })

      assert [{"workspace:ws-456", {:project_updated, "proj-123", "New Name"}}] =
               LegacyBridge.translate(event)
    end

    test "ProjectDeleted translates to legacy project_removed tuple" do
      event =
        ProjectDeleted.new(%{
          aggregate_id: "proj-123",
          actor_id: "user-1",
          project_id: "proj-123",
          workspace_id: "ws-456",
          user_id: "user-1"
        })

      assert [{"workspace:ws-456", {:project_removed, "proj-123"}}] =
               LegacyBridge.translate(event)
    end
  end

  # --- Documents Context ---

  describe "translate/1 - Documents" do
    test "DocumentCreated translates to legacy document_created tuple" do
      legacy_data = %{id: "doc-123", title: "My Doc"}

      event =
        DocumentCreated.new(%{
          aggregate_id: "doc-123",
          actor_id: "user-1",
          document_id: "doc-123",
          workspace_id: "ws-456",
          project_id: "proj-1",
          user_id: "user-1",
          title: "My Doc",
          metadata: %{legacy_data: legacy_data}
        })

      assert [{"workspace:ws-456", {:document_created, document_data}}] =
               LegacyBridge.translate(event)

      assert document_data == legacy_data
    end

    test "DocumentDeleted translates to legacy document_deleted tuple" do
      event =
        DocumentDeleted.new(%{
          aggregate_id: "doc-123",
          actor_id: "user-1",
          document_id: "doc-123",
          workspace_id: "ws-456",
          user_id: "user-1"
        })

      assert [{"workspace:ws-456", {:document_deleted, "doc-123"}}] =
               LegacyBridge.translate(event)
    end

    test "DocumentTitleChanged translates to dual-topic legacy tuples" do
      event =
        DocumentTitleChanged.new(%{
          aggregate_id: "doc-123",
          actor_id: "user-1",
          document_id: "doc-123",
          workspace_id: "ws-456",
          user_id: "user-1",
          title: "New Title"
        })

      translations = LegacyBridge.translate(event)

      assert {"workspace:ws-456", {:document_title_changed, "doc-123", "New Title"}} in translations

      assert {"document:doc-123", {:document_title_changed, "doc-123", "New Title"}} in translations

      assert length(translations) == 2
    end

    test "DocumentVisibilityChanged translates to dual-topic legacy tuples" do
      event =
        DocumentVisibilityChanged.new(%{
          aggregate_id: "doc-123",
          actor_id: "user-1",
          document_id: "doc-123",
          workspace_id: "ws-456",
          user_id: "user-1",
          is_public: true
        })

      translations = LegacyBridge.translate(event)

      assert {"workspace:ws-456", {:document_visibility_changed, "doc-123", true}} in translations

      assert {"document:doc-123", {:document_visibility_changed, "doc-123", true}} in translations

      assert length(translations) == 2
    end

    test "DocumentPinnedChanged translates to dual-topic legacy tuples" do
      event =
        DocumentPinnedChanged.new(%{
          aggregate_id: "doc-123",
          actor_id: "user-1",
          document_id: "doc-123",
          workspace_id: "ws-456",
          user_id: "user-1",
          is_pinned: true
        })

      translations = LegacyBridge.translate(event)

      assert {"workspace:ws-456", {:document_pinned_changed, "doc-123", true}} in translations
      assert {"document:doc-123", {:document_pinned_changed, "doc-123", true}} in translations
      assert length(translations) == 2
    end
  end

  # --- Agents Context ---

  describe "translate/1 - Agents" do
    test "AgentUpdated translates to workspace + user topics" do
      agent_data = %{id: "agent-1", name: "Bot"}
      msg = {:workspace_agent_updated, agent_data}

      event =
        AgentUpdated.new(%{
          aggregate_id: "agent-1",
          actor_id: "user-1",
          agent_id: "agent-1",
          user_id: "user-1",
          workspace_ids: ["ws-1", "ws-2"],
          metadata: %{legacy_data: agent_data}
        })

      translations = LegacyBridge.translate(event)

      assert {"workspace:ws-1", msg} in translations
      assert {"workspace:ws-2", msg} in translations
      assert {"user:user-1", msg} in translations
      assert length(translations) == 3
    end

    test "AgentDeleted translates same as AgentUpdated (legacy reuse)" do
      agent_data = %{id: "agent-1", name: "Bot"}
      msg = {:workspace_agent_updated, agent_data}

      event =
        AgentDeleted.new(%{
          aggregate_id: "agent-1",
          actor_id: "user-1",
          agent_id: "agent-1",
          user_id: "user-1",
          workspace_ids: ["ws-1"],
          metadata: %{legacy_data: agent_data}
        })

      translations = LegacyBridge.translate(event)

      assert {"workspace:ws-1", msg} in translations
      assert {"user:user-1", msg} in translations
      assert length(translations) == 2
    end

    test "AgentAddedToWorkspace translates to workspace + user topics" do
      agent_data = %{id: "agent-1", name: "Bot"}
      msg = {:workspace_agent_updated, agent_data}

      event =
        AgentAddedToWorkspace.new(%{
          aggregate_id: "agent-1",
          actor_id: "user-1",
          agent_id: "agent-1",
          workspace_id: "ws-1",
          user_id: "user-1",
          metadata: %{legacy_data: agent_data}
        })

      translations = LegacyBridge.translate(event)

      assert {"workspace:ws-1", msg} in translations
      assert {"user:user-1", msg} in translations
      assert length(translations) == 2
    end

    test "AgentRemovedFromWorkspace translates to workspace + user topics" do
      agent_data = %{id: "agent-1", name: "Bot"}
      msg = {:workspace_agent_updated, agent_data}

      event =
        AgentRemovedFromWorkspace.new(%{
          aggregate_id: "agent-1",
          actor_id: "user-1",
          agent_id: "agent-1",
          workspace_id: "ws-1",
          user_id: "user-1",
          metadata: %{legacy_data: agent_data}
        })

      translations = LegacyBridge.translate(event)

      assert {"workspace:ws-1", msg} in translations
      assert {"user:user-1", msg} in translations
      assert length(translations) == 2
    end
  end

  # --- Notifications Context ---

  describe "translate/1 - Notifications" do
    test "NotificationCreated translates to user notifications topic" do
      notification_data = %{id: "notif-1", type: "workspace_invitation"}

      event =
        NotificationCreated.new(%{
          aggregate_id: "notif-1",
          actor_id: "system",
          notification_id: "notif-1",
          user_id: "user-1",
          type: "workspace_invitation",
          metadata: %{legacy_data: notification_data}
        })

      assert [{"user:user-1:notifications", {:new_notification, data}}] =
               LegacyBridge.translate(event)

      assert data == notification_data
    end

    test "NotificationActionTaken with action=accepted translates to workspace_joined + member_joined" do
      event =
        NotificationActionTaken.new(%{
          aggregate_id: "notif-1",
          actor_id: "user-1",
          notification_id: "notif-1",
          user_id: "user-1",
          action: "accepted",
          workspace_id: "ws-1"
        })

      translations = LegacyBridge.translate(event)

      assert {"user:user-1", {:workspace_joined, "ws-1"}} in translations
      assert {"workspace:ws-1", {:member_joined, "user-1"}} in translations
      assert length(translations) == 2
    end

    test "NotificationActionTaken with action=declined translates to invitation_declined" do
      event =
        NotificationActionTaken.new(%{
          aggregate_id: "notif-1",
          actor_id: "user-1",
          notification_id: "notif-1",
          user_id: "user-1",
          action: "declined",
          workspace_id: "ws-1"
        })

      assert [{"workspace:ws-1", {:invitation_declined, "user-1"}}] =
               LegacyBridge.translate(event)
    end
  end

  # --- Identity Context ---

  describe "translate/1 - Identity" do
    test "MemberInvited translates to legacy workspace_invitations tuple" do
      event =
        MemberInvited.new(%{
          aggregate_id: "ws-123:user-456",
          actor_id: "inviter-789",
          user_id: "user-456",
          workspace_id: "ws-123",
          workspace_name: "Test Workspace",
          invited_by_name: "John Doe",
          role: "member"
        })

      assert [
               {"workspace_invitations",
                {:workspace_invitation_created,
                 %{
                   user_id: "user-456",
                   workspace_id: "ws-123",
                   workspace_name: "Test Workspace",
                   invited_by_name: "John Doe",
                   role: "member"
                 }}}
             ] = LegacyBridge.translate(event)
    end
  end

  # --- Catch-all ---

  describe "translate/1 - unknown events" do
    test "unknown event returns empty list (catch-all)" do
      event =
        UnknownEvent.new(%{
          aggregate_id: "agg-1",
          actor_id: "user-1",
          data: "some-data"
        })

      assert [] = LegacyBridge.translate(event)
    end
  end

  describe "broadcast_legacy/1" do
    test "returns :ok for unknown events with no translations" do
      event =
        UnknownEvent.new(%{
          aggregate_id: "agg-1",
          actor_id: "user-1",
          data: "some-data"
        })

      assert :ok = LegacyBridge.broadcast_legacy(event)
    end
  end
end
