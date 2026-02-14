defmodule Identity.Infrastructure.Notifiers.PubSubNotifierTest do
  use ExUnit.Case, async: true

  alias Identity.Infrastructure.Notifiers.PubSubNotifier

  describe "broadcast_invitation_created/5" do
    test "broadcasts to workspace_invitations topic" do
      # Subscribe to the topic
      Phoenix.PubSub.subscribe(Jarga.PubSub, "workspace_invitations")

      user_id = "user-123"
      workspace_id = "workspace-456"
      workspace_name = "Test Workspace"
      invited_by_name = "Jane Smith"
      role = "admin"

      assert :ok =
               PubSubNotifier.broadcast_invitation_created(
                 user_id,
                 workspace_id,
                 workspace_name,
                 invited_by_name,
                 role
               )

      assert_receive {:workspace_invitation_created,
                      %{
                        user_id: "user-123",
                        workspace_id: "workspace-456",
                        workspace_name: "Test Workspace",
                        invited_by_name: "Jane Smith",
                        role: "admin"
                      }}
    end
  end
end
