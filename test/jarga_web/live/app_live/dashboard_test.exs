defmodule JargaWeb.AppLive.DashboardTest do
  use JargaWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Jarga.AccountsFixtures
  import Jarga.WorkspacesFixtures

  alias Jarga.Workspaces

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
      _workspace = workspace_fixture(user, %{
        name: "Test Workspace",
        description: "This is a test description"
      })

      {:ok, _lv, html} = live(conn, ~p"/app")

      assert html =~ "This is a test description"
    end

    test "displays workspace colors", %{conn: conn, user: user} do
      workspace = workspace_fixture(user, %{
        name: "Colorful Workspace",
        color: "#FF5733"
      })

      {:ok, lv, _html} = live(conn, ~p"/app")

      # Verify color bar is displayed with the correct color
      assert lv
             |> element("[data-workspace-id='#{workspace.id}'] [style*='background-color: #{workspace.color}']")
             |> has_element?()
    end

    test "has a new workspace button", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/app")

      assert lv |> element("a", "New Workspace") |> has_element?()
    end

    test "workspace cards are clickable and navigate to workspace show page", %{conn: conn, user: user} do
      workspace = workspace_fixture(user, %{name: "Test Workspace"})

      {:ok, lv, _html} = live(conn, ~p"/app")

      assert {:error, {:live_redirect, %{to: redirect_path}}} =
               lv |> element("[data-workspace-id='#{workspace.id}']") |> render_click()

      assert redirect_path == ~p"/app/workspaces/#{workspace.slug}"
    end

    test "updates workspace list in real-time when user is added to a workspace", %{conn: conn, user: user} do
      {:ok, lv, _html} = live(conn, ~p"/app")

      # Verify no workspaces initially
      assert render(lv) =~ "No workspaces yet"

      # Create a workspace with another user and invite current user
      other_user = user_fixture()
      workspace = workspace_fixture(other_user, %{name: "Team Workspace"})

      # Add the user to the workspace (this will trigger the PubSub broadcast)
      {:ok, {:member_added, _member}} = Workspaces.invite_member(other_user, workspace.id, user.email, :member)

      # Verify workspace appears in the UI
      assert render(lv) =~ "Team Workspace"
      assert lv |> element("[data-workspace-id='#{workspace.id}']") |> has_element?()
    end

    test "updates workspace list in real-time when user is removed from a workspace", %{conn: conn, user: user} do
      # Create a workspace with two members
      other_user = user_fixture()
      workspace = workspace_fixture(other_user, %{name: "To Be Removed"})
      {:ok, {:member_added, _member}} = Workspaces.invite_member(other_user, workspace.id, user.email, :member)

      {:ok, lv, _html} = live(conn, ~p"/app")

      # Verify workspace is displayed
      assert render(lv) =~ "To Be Removed"
      assert lv |> element("[data-workspace-id='#{workspace.id}']") |> has_element?()

      # Remove the user from the workspace (this will trigger the PubSub broadcast)
      {:ok, _deleted_member} = Workspaces.remove_member(other_user, workspace.id, user.email)

      # Verify workspace is removed from the UI
      refute render(lv) =~ "To Be Removed"
      refute lv |> element("[data-workspace-id='#{workspace.id}']") |> has_element?()
    end

    test "updates workspace name in real-time when workspace is updated", %{conn: conn, user: user} do
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
end
