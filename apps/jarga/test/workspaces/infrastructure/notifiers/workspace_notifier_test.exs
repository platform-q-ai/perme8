defmodule Jarga.Workspaces.WorkspaceNotifierTest do
  use Jarga.DataCase, async: true

  alias Jarga.Workspaces.Infrastructure.Notifiers.WorkspaceNotifier

  import Jarga.AccountsFixtures
  import Jarga.WorkspacesFixtures

  describe "deliver_invitation_to_new_user/4" do
    test "sends invitation email to new user" do
      inviter = user_fixture(%{first_name: "John", last_name: "Doe"})
      workspace = workspace_fixture(inviter, %{name: "Test Workspace"})
      new_user_email = "newuser@example.com"
      signup_url = "http://example.com/signup"

      assert {:ok, email} =
               WorkspaceNotifier.deliver_invitation_to_new_user(
                 new_user_email,
                 workspace,
                 inviter,
                 signup_url
               )

      assert email.to == [{"", "newuser@example.com"}]
      assert email.from == {"Jarga", "contact@example.com"}
      assert email.subject == "You've been invited to Test Workspace on Jarga"
      assert email.text_body =~ "John Doe has invited you"
      assert email.text_body =~ "Test Workspace"
      assert email.text_body =~ signup_url
      assert email.text_body =~ "Sign up"
    end

    test "includes workspace name in subject" do
      inviter = user_fixture()
      workspace = workspace_fixture(inviter, %{name: "My Awesome Workspace"})
      email_addr = "test@example.com"
      url = "http://example.com/signup"

      {:ok, email} =
        WorkspaceNotifier.deliver_invitation_to_new_user(email_addr, workspace, inviter, url)

      assert email.subject == "You've been invited to My Awesome Workspace on Jarga"
    end

    test "includes inviter name in body" do
      inviter = user_fixture(%{first_name: "Jane", last_name: "Smith"})
      workspace = workspace_fixture(inviter)
      email_addr = "test@example.com"
      url = "http://example.com/signup"

      {:ok, email} =
        WorkspaceNotifier.deliver_invitation_to_new_user(email_addr, workspace, inviter, url)

      assert email.text_body =~ "Jane Smith"
    end

    test "includes signup URL in body" do
      inviter = user_fixture()
      workspace = workspace_fixture(inviter)
      email_addr = "test@example.com"
      signup_url = "http://custom.url/signup/token123"

      {:ok, email} =
        WorkspaceNotifier.deliver_invitation_to_new_user(
          email_addr,
          workspace,
          inviter,
          signup_url
        )

      assert email.text_body =~ signup_url
    end

    test "sends to correct recipient" do
      inviter = user_fixture()
      workspace = workspace_fixture(inviter)
      recipient_email = "specific@example.com"
      url = "http://example.com/signup"

      {:ok, email} =
        WorkspaceNotifier.deliver_invitation_to_new_user(
          recipient_email,
          workspace,
          inviter,
          url
        )

      assert email.to == [{"", "specific@example.com"}]
    end
  end

  describe "deliver_invitation_to_existing_user/4" do
    test "sends invitation email to existing user" do
      inviter = user_fixture(%{first_name: "Alice", last_name: "Johnson"})
      existing_user = user_fixture(%{first_name: "Bob", email: "bob@example.com"})
      workspace = workspace_fixture(inviter, %{name: "Collaboration Space"})
      workspace_url = "http://example.com/workspaces/123"

      assert {:ok, email} =
               WorkspaceNotifier.deliver_invitation_to_existing_user(
                 existing_user,
                 workspace,
                 inviter,
                 workspace_url
               )

      assert email.to == [{"", "bob@example.com"}]
      assert email.from == {"Jarga", "contact@example.com"}
      assert email.subject == "You've been invited to Collaboration Space"
      assert email.text_body =~ "Hi Bob"
      assert email.text_body =~ "Alice Johnson has invited you"
      assert email.text_body =~ "Collaboration Space"
      assert email.text_body =~ workspace_url
      assert email.text_body =~ "automatically added"
    end

    test "includes workspace name in subject" do
      inviter = user_fixture()
      user = user_fixture()
      workspace = workspace_fixture(inviter, %{name: "Engineering Team"})
      url = "http://example.com/workspace"

      {:ok, email} =
        WorkspaceNotifier.deliver_invitation_to_existing_user(user, workspace, inviter, url)

      assert email.subject == "You've been invited to Engineering Team"
    end

    test "addresses user by first name" do
      inviter = user_fixture()
      user = user_fixture(%{first_name: "Charlie", email: "charlie@example.com"})
      workspace = workspace_fixture(inviter)
      url = "http://example.com/workspace"

      {:ok, email} =
        WorkspaceNotifier.deliver_invitation_to_existing_user(user, workspace, inviter, url)

      assert email.text_body =~ "Hi Charlie"
    end

    test "includes inviter full name in body" do
      inviter = user_fixture(%{first_name: "David", last_name: "Williams"})
      user = user_fixture()
      workspace = workspace_fixture(inviter)
      url = "http://example.com/workspace"

      {:ok, email} =
        WorkspaceNotifier.deliver_invitation_to_existing_user(user, workspace, inviter, url)

      assert email.text_body =~ "David Williams"
    end

    test "includes workspace URL in body" do
      inviter = user_fixture()
      user = user_fixture()
      workspace = workspace_fixture(inviter)
      workspace_url = "http://custom.url/workspaces/abc-123"

      {:ok, email} =
        WorkspaceNotifier.deliver_invitation_to_existing_user(
          user,
          workspace,
          inviter,
          workspace_url
        )

      assert email.text_body =~ workspace_url
    end

    test "sends to user's email address" do
      inviter = user_fixture()
      user = user_fixture(%{email: "targetuser@example.com"})
      workspace = workspace_fixture(inviter)
      url = "http://example.com/workspace"

      {:ok, email} =
        WorkspaceNotifier.deliver_invitation_to_existing_user(user, workspace, inviter, url)

      assert email.to == [{"", "targetuser@example.com"}]
    end
  end
end
