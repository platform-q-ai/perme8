defmodule Identity.Infrastructure.Notifiers.PubSubNotifierTest do
  use ExUnit.Case, async: true

  alias Identity.Infrastructure.Notifiers.PubSubNotifier

  describe "broadcast_invitation_created/5" do
    test "returns :ok (no-op — EventBus handles delivery now)" do
      assert :ok =
               PubSubNotifier.broadcast_invitation_created(
                 "user-123",
                 "workspace-456",
                 "Test Workspace",
                 "Jane Smith",
                 "admin"
               )
    end

    test "does not broadcast to legacy workspace_invitations topic" do
      Phoenix.PubSub.subscribe(Jarga.PubSub, "workspace_invitations")

      PubSubNotifier.broadcast_invitation_created(
        "user-123",
        "workspace-456",
        "Test Workspace",
        "Jane Smith",
        "admin"
      )

      refute_receive {:workspace_invitation_created, _}
    end
  end
end
