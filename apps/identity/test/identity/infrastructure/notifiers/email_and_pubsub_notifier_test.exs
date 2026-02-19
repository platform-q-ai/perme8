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

    test "does not broadcast legacy PubSub tuple" do
      user = %User{
        id: "user-no-legacy",
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

      # Subscribe to the old legacy topic
      Phoenix.PubSub.subscribe(Jarga.PubSub, "user:user-no-legacy")

      EmailAndPubSubNotifier.notify_existing_user(user, workspace, inviter)

      refute_receive {:workspace_invitation, _, _, _}
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
    test "returns :ok" do
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

      assert :ok = EmailAndPubSubNotifier.notify_user_removed(user, workspace)
    end

    test "does not broadcast legacy PubSub tuple" do
      user = %User{
        id: "user-no-legacy-2",
        email: "user@example.com",
        first_name: "John",
        last_name: "Doe"
      }

      workspace = %Workspace{
        id: "workspace-456",
        name: "Test Workspace",
        slug: "test-workspace"
      }

      # Subscribe to the old legacy topic
      Phoenix.PubSub.subscribe(Jarga.PubSub, "user:user-no-legacy-2")

      EmailAndPubSubNotifier.notify_user_removed(user, workspace)

      refute_receive {:workspace_removed, _}
    end
  end

  describe "notify_workspace_updated/1" do
    test "returns :ok" do
      workspace = %Workspace{
        id: "workspace-456",
        name: "Test Workspace",
        slug: "test-workspace"
      }

      assert :ok = EmailAndPubSubNotifier.notify_workspace_updated(workspace)
    end

    test "does not broadcast legacy PubSub tuple" do
      workspace = %Workspace{
        id: "workspace-no-legacy",
        name: "Test Workspace",
        slug: "test-workspace"
      }

      # Subscribe to the old legacy topic
      Phoenix.PubSub.subscribe(Jarga.PubSub, "workspace:workspace-no-legacy")

      EmailAndPubSubNotifier.notify_workspace_updated(workspace)

      refute_receive {:workspace_updated, _, _}
    end
  end
end
