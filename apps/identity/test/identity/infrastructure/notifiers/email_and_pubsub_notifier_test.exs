defmodule Identity.Infrastructure.Notifiers.EmailAndPubSubNotifierTest do
  use ExUnit.Case, async: true

  alias Identity.Infrastructure.Notifiers.EmailAndPubSubNotifier
  alias Identity.Domain.Entities.{User, Workspace}

  describe "notify_existing_user/3" do
    test "returns :ok for valid inputs" do
      user = %User{
        id: "user-123",
        email: "user@example.com",
        first_name: "John",
        last_name: "Doe"
      }

      workspace = %Workspace{
        id: "workspace-456",
        name: "Test Workspace",
        slug: "test-workspace"
      }

      inviter = %User{
        id: "inviter-789",
        email: "inviter@example.com",
        first_name: "Jane",
        last_name: "Smith"
      }

      assert :ok = EmailAndPubSubNotifier.notify_existing_user(user, workspace, inviter)
    end
  end

  describe "notify_new_user/3" do
    test "returns :ok for valid inputs" do
      email = "newuser@example.com"

      workspace = %Workspace{
        id: "workspace-456",
        name: "Test Workspace",
        slug: "test-workspace"
      }

      inviter = %User{
        id: "inviter-789",
        email: "inviter@example.com",
        first_name: "Jane",
        last_name: "Smith"
      }

      assert :ok = EmailAndPubSubNotifier.notify_new_user(email, workspace, inviter)
    end

    test "sends email with correct registration URL" do
      email = "newuser@example.com"

      workspace = %Workspace{
        id: "workspace-456",
        name: "Test Workspace",
        slug: "test-workspace"
      }

      inviter = %User{
        id: "inviter-789",
        email: "inviter@example.com",
        first_name: "Jane",
        last_name: "Smith"
      }

      :ok = EmailAndPubSubNotifier.notify_new_user(email, workspace, inviter)

      assert_received {:email, sent_email}
      assert sent_email.text_body =~ "/users/register"
    end
  end

  describe "notify_user_removed/2" do
    test "returns :ok and broadcasts PubSub removal event" do
      user = %User{
        id: "user-123",
        email: "user@example.com",
        first_name: "John",
        last_name: "Doe"
      }

      workspace = %Workspace{
        id: "workspace-456",
        name: "Test Workspace",
        slug: "test-workspace"
      }

      # Subscribe to user topic
      Phoenix.PubSub.subscribe(Jarga.PubSub, "user:user-123")

      assert :ok = EmailAndPubSubNotifier.notify_user_removed(user, workspace)

      assert_receive {:workspace_removed, "workspace-456"}
    end
  end

  describe "notify_workspace_updated/1" do
    test "returns :ok and broadcasts PubSub update event" do
      workspace = %Workspace{
        id: "workspace-456",
        name: "Test Workspace",
        slug: "test-workspace"
      }

      # Subscribe to workspace topic
      Phoenix.PubSub.subscribe(Jarga.PubSub, "workspace:workspace-456")

      assert :ok = EmailAndPubSubNotifier.notify_workspace_updated(workspace)

      assert_receive {:workspace_updated, "workspace-456", "Test Workspace"}
    end
  end
end
