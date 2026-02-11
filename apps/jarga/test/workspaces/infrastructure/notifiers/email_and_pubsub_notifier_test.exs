defmodule Jarga.Workspaces.Services.EmailAndPubSubNotifierTest do
  use ExUnit.Case, async: true

  alias Jarga.Workspaces.Infrastructure.Notifiers.EmailAndPubSubNotifier
  alias Identity.Domain.Entities.User

  describe "notify_existing_user/3" do
    test "returns :ok for valid inputs" do
      user = %User{
        id: "user-123",
        email: "user@example.com",
        first_name: "John",
        last_name: "Doe"
      }

      workspace = %Jarga.Workspaces.Domain.Entities.Workspace{
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

      # Test that the function returns :ok
      # Note: In a real test environment, we would mock the email and PubSub calls
      # For now, we're just testing the function signature and return value
      assert :ok = EmailAndPubSubNotifier.notify_existing_user(user, workspace, inviter)
    end
  end

  describe "notify_new_user/3" do
    test "returns :ok for valid inputs" do
      email = "newuser@example.com"

      workspace = %Jarga.Workspaces.Domain.Entities.Workspace{
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

      workspace = %Jarga.Workspaces.Domain.Entities.Workspace{
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

      # Call the notifier
      :ok = EmailAndPubSubNotifier.notify_new_user(email, workspace, inviter)

      # Check the last sent email (Swoosh sends {:email, %Swoosh.Email{}} messages)
      assert_received {:email, sent_email}

      # Verify the signup URL points to /users/register, not /login
      assert sent_email.text_body =~ "/users/register"
      refute sent_email.text_body =~ "/login"
    end
  end

  describe "notify_user_removed/2" do
    test "returns :ok for valid inputs" do
      user = %User{
        id: "user-123",
        email: "user@example.com",
        first_name: "John",
        last_name: "Doe"
      }

      workspace = %Jarga.Workspaces.Domain.Entities.Workspace{
        id: "workspace-456",
        name: "Test Workspace",
        slug: "test-workspace"
      }

      assert :ok = EmailAndPubSubNotifier.notify_user_removed(user, workspace)
    end
  end

  describe "notify_workspace_updated/1" do
    test "returns :ok for valid inputs" do
      workspace = %Jarga.Workspaces.Domain.Entities.Workspace{
        id: "workspace-456",
        name: "Test Workspace",
        slug: "test-workspace"
      }

      assert :ok = EmailAndPubSubNotifier.notify_workspace_updated(workspace)
    end
  end
end
