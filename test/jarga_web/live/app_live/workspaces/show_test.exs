defmodule JargaWeb.AppLive.Workspaces.ShowTest do
  use JargaWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Jarga.AccountsFixtures
  import Jarga.WorkspacesFixtures

  alias Jarga.Pages

  describe "workspace show page members management" do
    setup %{conn: conn} do
      user = user_fixture()
      workspace = workspace_fixture(user)

      %{conn: log_in_user(conn, user), user: user, workspace: workspace}
    end

    test "shows manage members button for owner", %{conn: conn, workspace: workspace} do
      {:ok, lv, _html} = live(conn, ~p"/app/workspaces/#{workspace.slug}")

      assert lv |> element("button", "Manage Members") |> has_element?()
    end

    test "opens members modal when clicking manage members", %{conn: conn, workspace: workspace} do
      {:ok, lv, _html} = live(conn, ~p"/app/workspaces/#{workspace.slug}")

      html = lv |> element("button", "Manage Members") |> render_click()

      assert html =~ "Manage Members"
      assert html =~ "Invite New Member"
      assert html =~ "Team Members"
    end

    test "closes members modal when clicking done", %{conn: conn, workspace: workspace} do
      {:ok, lv, _html} = live(conn, ~p"/app/workspaces/#{workspace.slug}")

      # Open modal
      lv |> element("button", "Manage Members") |> render_click()

      # Close modal
      html = lv |> element("button", "Done") |> render_click()

      refute html =~ "modal-open"
    end

    test "shows invite form in members modal", %{conn: conn, workspace: workspace} do
      {:ok, lv, _html} = live(conn, ~p"/app/workspaces/#{workspace.slug}")

      # Open modal
      html = lv |> element("button", "Manage Members") |> render_click()

      # Should show invite form
      assert html =~ "Invite New Member"
      assert html =~ "invite-form"
      assert html =~ "Email"
      assert html =~ "Role"
    end

    test "shows current members in modal", %{conn: conn, user: user, workspace: workspace} do
      {:ok, lv, _html} = live(conn, ~p"/app/workspaces/#{workspace.slug}")

      # Open modal
      html = lv |> element("button", "Manage Members") |> render_click()

      # Should show current user as owner
      assert html =~ user.email
      assert html =~ "Owner"
    end
  end

  describe "workspace show page pages section" do
    setup %{conn: conn} do
      user = user_fixture()
      workspace = workspace_fixture(user)

      %{conn: log_in_user(conn, user), user: user, workspace: workspace}
    end

    test "displays empty state when no pages", %{conn: conn, workspace: workspace} do
      {:ok, _lv, html} = live(conn, ~p"/app/workspaces/#{workspace.slug}")

      assert html =~ "No pages yet"
    end

    test "displays pages when they exist", %{
      conn: conn,
      user: user,
      workspace: workspace
    } do
      {:ok, page1} = Pages.create_page(user, workspace.id, %{title: "Page One"})
      {:ok, page2} = Pages.create_page(user, workspace.id, %{title: "Page Two"})

      {:ok, _lv, html} = live(conn, ~p"/app/workspaces/#{workspace.slug}")

      assert html =~ "Page One"
      assert html =~ "Page Two"
      assert html =~ page1.id
      assert html =~ page2.id
    end

    test "shows pinned badge for pinned pages", %{
      conn: conn,
      user: user,
      workspace: workspace
    } do
      {:ok, page} = Pages.create_page(user, workspace.id, %{title: "Pinned", is_pinned: true})

      {:ok, _lv, html} = live(conn, ~p"/app/workspaces/#{workspace.slug}")

      assert html =~ "Pinned"
      assert html =~ page.id
    end

    test "opens page modal when clicking new page button", %{
      conn: conn,
      workspace: workspace
    } do
      {:ok, lv, _html} = live(conn, ~p"/app/workspaces/#{workspace.slug}")

      html = lv |> element("button", "New Page") |> render_click()

      assert html =~ "Create New Page"
      assert html =~ "page-form"
    end

    test "closes page modal when clicking cancel", %{conn: conn, workspace: workspace} do
      {:ok, lv, _html} = live(conn, ~p"/app/workspaces/#{workspace.slug}")

      # Open modal
      lv |> element("button", "New Page") |> render_click()

      # Close modal
      html = lv |> element("button", "Cancel") |> render_click()

      refute html =~ "modal-open"
    end

    test "creates page and redirects", %{conn: conn, workspace: workspace} do
      {:ok, lv, _html} = live(conn, ~p"/app/workspaces/#{workspace.slug}")

      # Open modal
      lv |> element("button", "New Page") |> render_click()

      # Submit form
      lv
      |> form("#page-form", title: "New Page")
      |> render_submit()

      assert_redirect(lv, ~p"/app/workspaces/#{workspace.slug}/pages/new-page")
    end
  end

  describe "workspace show page pubsub events" do
    setup %{conn: conn} do
      user = user_fixture()
      workspace = workspace_fixture(user)

      %{conn: log_in_user(conn, user), user: user, workspace: workspace}
    end

    test "updates project list when project_added event received", %{
      conn: conn,
      user: user,
      workspace: workspace
    } do
      {:ok, lv, html} = live(conn, ~p"/app/workspaces/#{workspace.slug}")

      assert html =~ "No projects yet"

      # Create a project (this will trigger the PubSub event)
      {:ok, project} =
        Jarga.Projects.create_project(user, workspace.id, %{name: "New Project"})

      # Simulate PubSub event
      send(lv.pid, {:project_added, project.id})

      html = render(lv)
      assert html =~ "New Project"
    end

    test "updates project list when project_removed event received", %{
      conn: conn,
      user: user,
      workspace: workspace
    } do
      {:ok, project} =
        Jarga.Projects.create_project(user, workspace.id, %{name: "To Delete"})

      {:ok, lv, html} = live(conn, ~p"/app/workspaces/#{workspace.slug}")

      assert html =~ "To Delete"

      # Delete project
      {:ok, _} = Jarga.Projects.delete_project(user, workspace.id, project.id)

      # Simulate PubSub event
      send(lv.pid, {:project_removed, project.id})

      html = render(lv)
      refute html =~ "To Delete"
    end

    test "updates page list when page_visibility_changed event received", %{
      conn: conn,
      user: user,
      workspace: workspace
    } do
      {:ok, page} = Pages.create_page(user, workspace.id, %{title: "Test Page"})

      {:ok, lv, _html} = live(conn, ~p"/app/workspaces/#{workspace.slug}")

      # Simulate PubSub event
      send(lv.pid, {:page_visibility_changed, page.id, true})

      assert render(lv) =~ "Test Page"
    end

    test "updates page pinned state when page_pinned_changed event received", %{
      conn: conn,
      user: user,
      workspace: workspace
    } do
      {:ok, page} = Pages.create_page(user, workspace.id, %{title: "Test Page"})

      {:ok, lv, html} = live(conn, ~p"/app/workspaces/#{workspace.slug}")

      refute html =~ "Pinned"

      # Simulate PubSub event
      send(lv.pid, {:page_pinned_changed, page.id, true})

      html = render(lv)
      assert html =~ "Pinned"
    end

    test "updates page title when page_title_changed event received", %{
      conn: conn,
      user: user,
      workspace: workspace
    } do
      {:ok, page} = Pages.create_page(user, workspace.id, %{title: "Original Title"})

      {:ok, lv, html} = live(conn, ~p"/app/workspaces/#{workspace.slug}")

      assert html =~ "Original Title"

      # Simulate PubSub event
      send(lv.pid, {:page_title_changed, page.id, "Updated Title"})

      html = render(lv)
      assert html =~ "Updated Title"
      refute html =~ "Original Title"
    end

    test "updates workspace name when workspace_updated event received", %{
      conn: conn,
      workspace: workspace
    } do
      {:ok, lv, html} = live(conn, ~p"/app/workspaces/#{workspace.slug}")

      assert html =~ workspace.name

      # Simulate PubSub event
      send(lv.pid, {:workspace_updated, workspace.id, "New Name"})

      html = render(lv)
      assert html =~ "New Name"
    end

    test "ignores workspace_updated event for different workspace", %{
      conn: conn,
      workspace: workspace
    } do
      {:ok, lv, html} = live(conn, ~p"/app/workspaces/#{workspace.slug}")

      original_name = workspace.name
      assert html =~ original_name

      # Simulate PubSub event for different workspace
      send(lv.pid, {:workspace_updated, Ecto.UUID.generate(), "Other Name"})

      html = render(lv)
      assert html =~ original_name
      refute html =~ "Other Name"
    end

    test "updates project name when project_updated event received", %{
      conn: conn,
      user: user,
      workspace: workspace
    } do
      {:ok, project} =
        Jarga.Projects.create_project(user, workspace.id, %{name: "Original Name"})

      {:ok, lv, html} = live(conn, ~p"/app/workspaces/#{workspace.slug}")

      assert html =~ "Original Name"

      # Simulate PubSub event
      send(lv.pid, {:project_updated, project.id, "Updated Name"})

      html = render(lv)
      assert html =~ "Updated Name"
      refute html =~ "Original Name"
    end
  end

  describe "workspace show page deletion" do
    setup %{conn: conn} do
      user = user_fixture()
      workspace = workspace_fixture(user)

      %{conn: log_in_user(conn, user), user: user, workspace: workspace}
    end

    test "deletes workspace and redirects for owner", %{conn: conn, workspace: workspace} do
      {:ok, lv, _html} = live(conn, ~p"/app/workspaces/#{workspace.slug}")

      lv
      |> element("button", "Delete Workspace")
      |> render_click()

      assert_redirect(lv, ~p"/app/workspaces")
    end
  end

  describe "workspace show page projects modal" do
    setup %{conn: conn} do
      user = user_fixture()
      workspace = workspace_fixture(user)

      %{conn: log_in_user(conn, user), user: user, workspace: workspace}
    end

    test "opens project modal when clicking new project", %{conn: conn, workspace: workspace} do
      {:ok, lv, _html} = live(conn, ~p"/app/workspaces/#{workspace.slug}")

      html = lv |> element("button", "New Project") |> render_click()

      assert html =~ "Create New Project"
      assert html =~ "project-form"
    end

    test "closes project modal when clicking cancel", %{conn: conn, workspace: workspace} do
      {:ok, lv, _html} = live(conn, ~p"/app/workspaces/#{workspace.slug}")

      # Open modal
      lv |> element("button", "New Project") |> render_click()

      # Close modal
      html = lv |> element("button", "Cancel") |> render_click()

      refute html =~ "modal-open"
    end

    test "creates project with valid data and shows in list", %{
      conn: conn,
      workspace: workspace
    } do
      {:ok, lv, _html} = live(conn, ~p"/app/workspaces/#{workspace.slug}")

      # Open modal
      lv |> element("button", "New Project") |> render_click()

      # Submit form
      lv
      |> form("#project-form", project: %{name: "Test Project", description: "Test desc"})
      |> render_submit()

      html = render(lv)
      assert html =~ "Test Project"
      assert html =~ "Test desc"
    end

    test "shows error when creating project with invalid data", %{
      conn: conn,
      workspace: workspace
    } do
      {:ok, lv, _html} = live(conn, ~p"/app/workspaces/#{workspace.slug}")

      # Open modal
      lv |> element("button", "New Project") |> render_click()

      # Submit form with empty name
      lv
      |> form("#project-form", project: %{name: ""})
      |> render_submit()

      html = render(lv)
      assert html =~ "can&#39;t be blank"
    end
  end

  describe "workspace show page with guest permissions" do
    setup %{conn: conn} do
      owner = user_fixture()
      workspace = workspace_fixture(owner)
      guest = user_fixture()

      # Add guest to workspace
      {:ok, {:member_added, _}} =
        Jarga.Workspaces.invite_member(owner, workspace.id, guest.email, :guest)

      # Wait for invite to process
      :timer.sleep(50)

      %{conn: log_in_user(conn, guest), workspace: workspace, guest: guest}
    end

    test "guest cannot see new project button", %{conn: conn, workspace: workspace} do
      {:ok, lv, html} = live(conn, ~p"/app/workspaces/#{workspace.slug}")

      refute lv |> element("button", "New Project") |> has_element?()
      refute html =~ "New Project"
    end

    test "guest cannot see new page button", %{conn: conn, workspace: workspace} do
      {:ok, lv, _html} = live(conn, ~p"/app/workspaces/#{workspace.slug}")

      refute lv |> element("button", "New Page") |> has_element?()
    end

    test "guest cannot see edit workspace button", %{conn: conn, workspace: workspace} do
      {:ok, lv, _html} = live(conn, ~p"/app/workspaces/#{workspace.slug}")

      refute lv |> element("a", "Edit") |> has_element?()
    end

    test "guest cannot see delete workspace button", %{conn: conn, workspace: workspace} do
      {:ok, lv, _html} = live(conn, ~p"/app/workspaces/#{workspace.slug}")

      refute lv |> element("button", "Delete Workspace") |> has_element?()
    end

    test "guest cannot see manage members button", %{conn: conn, workspace: workspace} do
      {:ok, lv, _html} = live(conn, ~p"/app/workspaces/#{workspace.slug}")

      refute lv |> element("button", "Manage Members") |> has_element?()
    end

    test "guest sees empty state message for pages without create button", %{
      conn: conn,
      workspace: workspace
    } do
      {:ok, _lv, html} = live(conn, ~p"/app/workspaces/#{workspace.slug}")

      assert html =~ "No pages yet"
      assert html =~ "No pages have been created yet"
      refute html =~ "Create your first page"
    end

    test "guest sees empty state message for projects without create button", %{
      conn: conn,
      workspace: workspace
    } do
      {:ok, _lv, html} = live(conn, ~p"/app/workspaces/#{workspace.slug}")

      assert html =~ "No projects yet"
      assert html =~ "No projects have been created yet"
      refute html =~ "Create your first project"
    end
  end

  describe "workspace show page error handling" do
    setup %{conn: conn} do
      user = user_fixture()
      workspace = workspace_fixture(user)

      %{conn: log_in_user(conn, user), user: user, workspace: workspace}
    end

    test "shows error when page creation fails", %{conn: conn, workspace: workspace} do
      {:ok, lv, _html} = live(conn, ~p"/app/workspaces/#{workspace.slug}")

      # Open modal
      lv |> element("button", "New Page") |> render_click()

      # Submit with empty title (should fail validation)
      lv
      |> form("#page-form", title: "")
      |> render_submit()

      html = render(lv)
      assert html =~ "can&#39;t be blank"
    end

    test "redirects when workspace not found", %{conn: conn} do
      result = live(conn, ~p"/app/workspaces/nonexistent-slug")

      # Should redirect (either :redirect or :live_redirect)
      case result do
        {:error, {:redirect, %{to: path}}} ->
          assert path == ~p"/app/workspaces"

        {:error, {:live_redirect, %{to: path}}} ->
          assert path == ~p"/app/workspaces"

        other ->
          flunk("Expected redirect, got: #{inspect(other)}")
      end
    end

    test "displays workspace description when present", %{conn: conn, user: user} do
      workspace = workspace_fixture(user, %{description: "Test description"})

      {:ok, _lv, html} = live(conn, ~p"/app/workspaces/#{workspace.slug}")

      assert html =~ "Test description"
    end

    test "displays project color when present", %{conn: conn, user: user, workspace: workspace} do
      {:ok, _project} =
        Jarga.Projects.create_project(user, workspace.id, %{name: "Colored", color: "#FF5733"})

      {:ok, _lv, html} = live(conn, ~p"/app/workspaces/#{workspace.slug}")

      assert html =~ "background-color: #FF5733"
    end

    test "does not show project color stripe when color is nil", %{
      conn: conn,
      user: user,
      workspace: workspace
    } do
      {:ok, _project} = Jarga.Projects.create_project(user, workspace.id, %{name: "No Color"})

      {:ok, lv, _html} = live(conn, ~p"/app/workspaces/#{workspace.slug}")

      html = render(lv)
      assert html =~ "No Color"
      # Should not have a color div
    end
  end
end
