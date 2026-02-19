defmodule JargaWeb.AppLive.DashboardTest do
  use JargaWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Jarga.AccountsFixtures
  import Jarga.WorkspacesFixtures

  alias Jarga.Workspaces

  # Cross-context domain events
  alias Identity.Domain.Events.{WorkspaceUpdated, MemberRemoved, WorkspaceInvitationNotified}
  alias Jarga.Notifications.Domain.Events.NotificationActionTaken

  # Agent domain events
  alias Agents.Domain.Events.{
    AgentUpdated,
    AgentDeleted,
    AgentAddedToWorkspace,
    AgentRemovedFromWorkspace
  }

  describe "dashboard page" do
    test "redirects if user is not logged in", %{conn: conn} do
      assert {:error, redirect} = live(conn, ~p"/app")

      assert {:redirect, %{to: path, flash: flash}} = redirect
      assert path == ~p"/users/log-in"
      assert %{"error" => "You must log in to access this page."} = flash
    end
  end

  describe "dashboard page (authenticated)" do
    setup %{conn: conn} do
      user = user_fixture()
      %{conn: log_in_user(conn, user), user: user}
    end

    test "renders dashboard page for authenticated user", %{conn: conn} do
      {:ok, _lv, html} = live(conn, ~p"/app")

      assert html =~ "Welcome to Jarga"
      assert html =~ "Your authenticated dashboard"
    end

    test "displays sidebar with navigation links", %{conn: conn, user: user} do
      {:ok, _lv, html} = live(conn, ~p"/app")

      # Sidebar should contain user info
      assert html =~ user.email
      assert html =~ user.first_name
      assert html =~ user.last_name

      # Sidebar navigation links
      assert html =~ "Home"
      assert html =~ "Settings"
      assert html =~ "Log out"

      # Theme switcher label
      assert html =~ "Theme"
    end

    test "sidebar has working navigation links", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/app")

      # Test home link exists
      assert lv |> element("a[href='/app']") |> has_element?()

      # Test settings link exists
      assert lv |> element("a[href='/users/settings']") |> has_element?()

      # Test logout link exists
      assert lv |> element("a[href='/users/log-out']") |> has_element?()
    end

    test "displays empty state when user has no workspaces", %{conn: conn} do
      {:ok, _lv, html} = live(conn, ~p"/app")

      assert html =~ "No workspaces yet"
      assert html =~ "Create your first workspace to get started"
    end

    test "displays list of user's workspaces", %{conn: conn, user: user} do
      workspace1 = workspace_fixture(user, %{name: "Personal Workspace"})
      workspace2 = workspace_fixture(user, %{name: "Team Workspace"})

      {:ok, _lv, html} = live(conn, ~p"/app")

      assert html =~ "Personal Workspace"
      assert html =~ "Team Workspace"
      assert html =~ workspace1.id
      assert html =~ workspace2.id
    end

    test "does not display other users' workspaces", %{conn: conn, user: user} do
      _my_workspace = workspace_fixture(user, %{name: "My Workspace"})

      other_user = user_fixture()
      _other_workspace = workspace_fixture(other_user, %{name: "Other Workspace"})

      {:ok, _lv, html} = live(conn, ~p"/app")

      assert html =~ "My Workspace"
      refute html =~ "Other Workspace"
    end

    test "displays workspace descriptions", %{conn: conn, user: user} do
      _workspace =
        workspace_fixture(user, %{
          name: "Test Workspace",
          description: "This is a test description"
        })

      {:ok, _lv, html} = live(conn, ~p"/app")

      assert html =~ "This is a test description"
    end

    test "displays workspace colors", %{conn: conn, user: user} do
      workspace =
        workspace_fixture(user, %{
          name: "Colorful Workspace",
          color: "#FF5733"
        })

      {:ok, lv, _html} = live(conn, ~p"/app")

      # Verify color bar is displayed with the correct color
      assert lv
             |> element(
               "[data-workspace-id='#{workspace.id}'] [style*='background-color: #{workspace.color}']"
             )
             |> has_element?()
    end

    test "has a new workspace button", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/app")

      assert lv |> element("a", "New Workspace") |> has_element?()
    end

    test "workspace cards are clickable and navigate to workspace show page", %{
      conn: conn,
      user: user
    } do
      workspace = workspace_fixture(user, %{name: "Test Workspace"})

      {:ok, lv, _html} = live(conn, ~p"/app")

      assert {:error, {:live_redirect, %{to: redirect_path}}} =
               lv |> element("[data-workspace-id='#{workspace.id}']") |> render_click()

      assert redirect_path == ~p"/app/workspaces/#{workspace.slug}"
    end

    test "updates workspace list in real-time when user is added to a workspace", %{
      conn: conn,
      user: user
    } do
      {:ok, lv, _html} = live(conn, ~p"/app")

      # Verify no workspaces initially
      assert render(lv) =~ "No workspaces yet"

      # Create a workspace with another user and invite current user
      other_user = user_fixture()
      workspace = workspace_fixture(other_user, %{name: "Team Workspace"})

      # Add the user to the workspace (this will trigger the PubSub broadcast)
      {:ok, _member} = invite_and_accept_member(other_user, workspace.id, user.email, :member)

      # Verify workspace appears in the UI
      assert render(lv) =~ "Team Workspace"
      assert lv |> element("[data-workspace-id='#{workspace.id}']") |> has_element?()
    end

    test "updates workspace list in real-time when user is removed from a workspace", %{
      conn: conn,
      user: user
    } do
      # Create a workspace with two members
      other_user = user_fixture()
      workspace = workspace_fixture(other_user, %{name: "To Be Removed"})

      {:ok, _member} = invite_and_accept_member(other_user, workspace.id, user.email, :member)

      {:ok, lv, _html} = live(conn, ~p"/app")

      # Verify workspace is displayed
      assert lv |> element("[data-workspace-id='#{workspace.id}']") |> has_element?()

      # Remove the user from the workspace (this will trigger the PubSub broadcast)
      {:ok, _deleted_member} = Workspaces.remove_member(other_user, workspace.id, user.email)

      # Verify workspace is removed from the workspaces list
      refute lv |> element("[data-workspace-id='#{workspace.id}']") |> has_element?()
    end

    test "updates workspace name in real-time when workspace is updated", %{
      conn: conn,
      user: user
    } do
      workspace = workspace_fixture(user, %{name: "Original Name"})

      {:ok, lv, _html} = live(conn, ~p"/app")

      # Verify original name is displayed
      assert render(lv) =~ "Original Name"

      # Update workspace name (simulating another user or process)
      {:ok, _updated} = Workspaces.update_workspace(user, workspace.id, %{name: "Updated Name"})

      # Verify updated name appears in the UI
      assert render(lv) =~ "Updated Name"
      refute render(lv) =~ "Original Name"
    end
  end

  describe "dashboard structured event handlers" do
    setup %{conn: conn} do
      user = user_fixture()
      %{conn: log_in_user(conn, user), user: user}
    end

    test "updates workspace name on WorkspaceUpdated event", %{conn: conn, user: user} do
      workspace = workspace_fixture(user, %{name: "Original Name"})

      {:ok, lv, _html} = live(conn, ~p"/app")
      assert render(lv) =~ "Original Name"

      event =
        WorkspaceUpdated.new(%{
          aggregate_id: workspace.id,
          actor_id: user.id,
          workspace_id: workspace.id,
          name: "Updated Name"
        })

      send(lv.pid, event)

      html = render(lv)
      assert html =~ "Updated Name"
      refute html =~ "Original Name"
    end

    test "reloads workspaces on WorkspaceInvitationNotified event", %{conn: conn, user: user} do
      {:ok, lv, _html} = live(conn, ~p"/app")
      assert render(lv) =~ "No workspaces yet"

      # Create workspace by another user, add current user as member
      other_user = user_fixture()
      workspace = workspace_fixture(other_user, %{name: "Invited Workspace"})
      {:ok, _member} = invite_and_accept_member(other_user, workspace.id, user.email, :member)

      # Send structured event
      event =
        WorkspaceInvitationNotified.new(%{
          aggregate_id: workspace.id,
          actor_id: other_user.id,
          workspace_id: workspace.id,
          target_user_id: user.id,
          workspace_name: "Invited Workspace",
          invited_by_name: "Other User"
        })

      send(lv.pid, event)

      html = render(lv)
      assert html =~ "Invited Workspace"
    end

    test "reloads workspaces on NotificationActionTaken accepted event when current user joined",
         %{
           conn: conn,
           user: user
         } do
      {:ok, lv, _html} = live(conn, ~p"/app")
      assert render(lv) =~ "No workspaces yet"

      # Create workspace by another user, add current user as member
      other_user = user_fixture()
      workspace = workspace_fixture(other_user, %{name: "Joined Workspace"})
      {:ok, _member} = invite_and_accept_member(other_user, workspace.id, user.email, :member)

      # Send structured event — "I joined a workspace"
      event =
        NotificationActionTaken.new(%{
          aggregate_id: Ecto.UUID.generate(),
          actor_id: user.id,
          notification_id: Ecto.UUID.generate(),
          user_id: user.id,
          action: "accepted",
          workspace_id: workspace.id
        })

      send(lv.pid, event)

      html = render(lv)
      assert html =~ "Joined Workspace"
    end

    test "ignores NotificationActionTaken accepted event when different user joined", %{
      conn: conn,
      user: user
    } do
      workspace = workspace_fixture(user, %{name: "My Workspace"})
      {:ok, lv, _html} = live(conn, ~p"/app")

      assert render(lv) =~ "My Workspace"

      # Send structured event — someone else joined (received via workspace topic)
      other_user_id = Ecto.UUID.generate()

      event =
        NotificationActionTaken.new(%{
          aggregate_id: Ecto.UUID.generate(),
          actor_id: other_user_id,
          notification_id: Ecto.UUID.generate(),
          user_id: other_user_id,
          action: "accepted",
          workspace_id: workspace.id
        })

      send(lv.pid, event)

      # Should still render normally — no-op for dashboard
      assert render(lv) =~ "My Workspace"
    end

    test "reloads workspaces on MemberRemoved event when current user is removed", %{
      conn: conn,
      user: user
    } do
      # Create workspace by other user with current user as member
      other_user = user_fixture()
      workspace = workspace_fixture(other_user, %{name: "Will Be Removed"})
      {:ok, _member} = invite_and_accept_member(other_user, workspace.id, user.email, :member)

      {:ok, lv, _html} = live(conn, ~p"/app")
      assert lv |> element("[data-workspace-id='#{workspace.id}']") |> has_element?()

      # Actually remove the member from DB
      {:ok, _} = Workspaces.remove_member(other_user, workspace.id, user.email)

      # Send structured event
      event =
        MemberRemoved.new(%{
          aggregate_id: workspace.id,
          actor_id: other_user.id,
          workspace_id: workspace.id,
          target_user_id: user.id
        })

      send(lv.pid, event)

      refute lv |> element("[data-workspace-id='#{workspace.id}']") |> has_element?()
    end

    test "ignores MemberRemoved event for different user", %{conn: conn, user: user} do
      workspace = workspace_fixture(user, %{name: "My Workspace"})
      {:ok, lv, _html} = live(conn, ~p"/app")

      assert render(lv) =~ "My Workspace"

      # Send structured event — different user was removed
      event =
        MemberRemoved.new(%{
          aggregate_id: workspace.id,
          actor_id: user.id,
          workspace_id: workspace.id,
          target_user_id: Ecto.UUID.generate()
        })

      send(lv.pid, event)

      # Workspace should still be visible
      assert render(lv) =~ "My Workspace"
    end

    test "handles AgentUpdated event by reloading user agents", %{conn: conn, user: user} do
      {:ok, lv, _html} = live(conn, ~p"/app")

      event =
        AgentUpdated.new(%{
          aggregate_id: Ecto.UUID.generate(),
          actor_id: user.id,
          agent_id: Ecto.UUID.generate(),
          user_id: user.id,
          workspace_ids: [],
          changes: %{name: "Updated Agent"}
        })

      send(lv.pid, event)
      assert render(lv)
    end

    test "handles AgentDeleted event by reloading user agents", %{conn: conn, user: user} do
      {:ok, lv, _html} = live(conn, ~p"/app")

      event =
        AgentDeleted.new(%{
          aggregate_id: Ecto.UUID.generate(),
          actor_id: user.id,
          agent_id: Ecto.UUID.generate(),
          user_id: user.id,
          workspace_ids: []
        })

      send(lv.pid, event)
      assert render(lv)
    end

    test "handles AgentAddedToWorkspace event", %{conn: conn, user: user} do
      workspace = workspace_fixture(user)
      {:ok, lv, _html} = live(conn, ~p"/app")

      event =
        AgentAddedToWorkspace.new(%{
          aggregate_id: Ecto.UUID.generate(),
          actor_id: user.id,
          agent_id: Ecto.UUID.generate(),
          user_id: user.id,
          workspace_id: workspace.id
        })

      send(lv.pid, event)
      assert render(lv)
    end

    test "handles AgentRemovedFromWorkspace event", %{conn: conn, user: user} do
      workspace = workspace_fixture(user)
      {:ok, lv, _html} = live(conn, ~p"/app")

      event =
        AgentRemovedFromWorkspace.new(%{
          aggregate_id: Ecto.UUID.generate(),
          actor_id: user.id,
          agent_id: Ecto.UUID.generate(),
          user_id: user.id,
          workspace_id: workspace.id
        })

      send(lv.pid, event)
      assert render(lv)
    end
  end
end
