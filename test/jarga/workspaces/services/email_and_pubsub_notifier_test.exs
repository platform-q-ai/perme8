defmodule Jarga.Workspaces.Services.EmailAndPubSubNotifierTest do
  use ExUnit.Case, async: true

  alias Jarga.Workspaces.Services.EmailAndPubSubNotifier

  describe "notify_existing_user/3" do
    test "returns :ok for valid inputs" do
      user = %Jarga.Accounts.User{
        id: "user-123",
        email: "user@example.com",
        first_name: "John",
        last_name: "Doe"
      }

      workspace = %Jarga.Workspaces.Workspace{
        id: "workspace-456",
        name: "Test Workspace",
        slug: "test-workspace"
      }

      inviter = %Jarga.Accounts.User{
        id: "inviter-789",
        email: "inviter@example.com",
        first_name: "Jane",
        last_name: "Smith"
      }

      # Test that the function returns :ok
      # Note: In a real test environment, we would mock the email and PubSub calls
      # For now, we're just testing the function signature and return value
      assert :ok = EmailAndPubSubNotifier.notify_existing_user(user, workspace, inviter)
    end
  end

  describe "notify_new_user/3" do
    test "returns :ok for valid inputs" do
      email = "newuser@example.com"

      workspace = %Jarga.Workspaces.Workspace{
        id: "workspace-456",
        name: "Test Workspace",
        slug: "test-workspace"
      }

      inviter = %Jarga.Accounts.User{
        id: "inviter-789",
        email: "inviter@example.com",
        first_name: "Jane",
        last_name: "Smith"
      }

      assert :ok = EmailAndPubSubNotifier.notify_new_user(email, workspace, inviter)
    end
  end

  describe "notify_user_removed/2" do
    test "returns :ok for valid inputs" do
      user = %Jarga.Accounts.User{
        id: "user-123",
        email: "user@example.com",
        first_name: "John",
        last_name: "Doe"
      }

      workspace = %Jarga.Workspaces.Workspace{
        id: "workspace-456",
        name: "Test Workspace",
        slug: "test-workspace"
      }

      assert :ok = EmailAndPubSubNotifier.notify_user_removed(user, workspace)
    end
  end

  describe "notify_workspace_updated/1" do
    test "returns :ok for valid inputs" do
      workspace = %Jarga.Workspaces.Workspace{
        id: "workspace-456",
        name: "Test Workspace",
        slug: "test-workspace"
      }

      assert :ok = EmailAndPubSubNotifier.notify_workspace_updated(workspace)
    end
  end
end
