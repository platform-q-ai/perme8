defmodule JargaWeb.AppLive.Projects.ShowTest do
  use JargaWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Jarga.AccountsFixtures
  import Jarga.WorkspacesFixtures
  import Jarga.ProjectsFixtures

  alias Jarga.Pages

  describe "show project page" do
    test "redirects if user is not logged in", %{conn: conn} do
      user = user_fixture()
      workspace = workspace_fixture(user)
      project = project_fixture(user, workspace)

      assert {:error, redirect} =
               live(conn, ~p"/app/workspaces/#{workspace.slug}/projects/#{project.slug}")

      assert {:redirect, %{to: path, flash: flash}} = redirect
      assert path == ~p"/users/log-in"
      assert %{"error" => "You must log in to access this page."} = flash
    end
  end

  describe "show project page (authenticated)" do
    setup %{conn: conn} do
      user = user_fixture()
      workspace = workspace_fixture(user)
      project = project_fixture(user, workspace)

      %{conn: log_in_user(conn, user), user: user, workspace: workspace, project: project}
    end

    test "renders project show page", %{conn: conn, workspace: workspace, project: project} do
      {:ok, _lv, html} =
        live(conn, ~p"/app/workspaces/#{workspace.slug}/projects/#{project.slug}")

      assert html =~ project.name
    end

    test "displays breadcrumbs", %{conn: conn, workspace: workspace, project: project} do
      {:ok, _lv, html} =
        live(conn, ~p"/app/workspaces/#{workspace.slug}/projects/#{project.slug}")

      assert html =~ "Home"
      assert html =~ "Workspaces"
      assert html =~ workspace.name
      assert html =~ project.name
    end

    test "displays project description when present", %{conn: conn, user: user} do
      workspace = workspace_fixture(user)
      project = project_fixture(user, workspace, %{description: "Test description"})

      {:ok, _lv, html} =
        live(conn, ~p"/app/workspaces/#{workspace.slug}/projects/#{project.slug}")

      assert html =~ "Test description"
    end

    test "displays edit button", %{conn: conn, workspace: workspace, project: project} do
      {:ok, lv, _html} =
        live(conn, ~p"/app/workspaces/#{workspace.slug}/projects/#{project.slug}")

      assert lv |> element("a", "Edit") |> has_element?()
    end

    test "displays delete button", %{conn: conn, workspace: workspace, project: project} do
      {:ok, lv, _html} =
        live(conn, ~p"/app/workspaces/#{workspace.slug}/projects/#{project.slug}")

      assert lv |> element("button", "Delete Project") |> has_element?()
    end

    test "displays empty state when no pages", %{
      conn: conn,
      workspace: workspace,
      project: project
    } do
      {:ok, _lv, html} =
        live(conn, ~p"/app/workspaces/#{workspace.slug}/projects/#{project.slug}")

      assert html =~ "No pages yet"
      assert html =~ "Create your first page for this project"
    end

    test "displays pages when they exist", %{
      conn: conn,
      user: user,
      workspace: workspace,
      project: project
    } do
      {:ok, page1} =
        Pages.create_page(user, workspace.id, %{title: "Page One", project_id: project.id})

      {:ok, page2} =
        Pages.create_page(user, workspace.id, %{title: "Page Two", project_id: project.id})

      {:ok, _lv, html} =
        live(conn, ~p"/app/workspaces/#{workspace.slug}/projects/#{project.slug}")

      refute html =~ "No pages yet"
      assert html =~ "Page One"
      assert html =~ "Page Two"
      assert html =~ page1.id
      assert html =~ page2.id
    end

    test "shows pinned badge for pinned pages", %{
      conn: conn,
      user: user,
      workspace: workspace,
      project: project
    } do
      {:ok, page} =
        Pages.create_page(user, workspace.id, %{
          title: "Pinned Page",
          project_id: project.id,
          is_pinned: true
        })

      {:ok, _lv, html} =
        live(conn, ~p"/app/workspaces/#{workspace.slug}/projects/#{project.slug}")

      assert html =~ "Pinned"
      assert html =~ page.id
    end

    test "displays new page button", %{conn: conn, workspace: workspace, project: project} do
      {:ok, lv, _html} =
        live(conn, ~p"/app/workspaces/#{workspace.slug}/projects/#{project.slug}")

      assert lv |> element("button", "New Page") |> has_element?()
    end

    test "shows page modal when clicking new page button", %{
      conn: conn,
      workspace: workspace,
      project: project
    } do
      {:ok, lv, _html} =
        live(conn, ~p"/app/workspaces/#{workspace.slug}/projects/#{project.slug}")

      refute render(lv) =~ "Create New Page"

      html =
        lv
        |> element("button", "New Page")
        |> render_click()

      assert html =~ "Create New Page"
      assert html =~ "modal-open"
    end

    test "hides page modal when clicking cancel", %{
      conn: conn,
      workspace: workspace,
      project: project
    } do
      {:ok, lv, _html} =
        live(conn, ~p"/app/workspaces/#{workspace.slug}/projects/#{project.slug}")

      # Show modal
      lv
      |> element("button", "New Page")
      |> render_click()

      # Hide modal
      html =
        lv
        |> element("button", "Cancel")
        |> render_click()

      refute html =~ "Create New Page"
      refute html =~ "modal-open"
    end

    test "creates page and redirects when submitting modal", %{
      conn: conn,
      workspace: workspace,
      project: project
    } do
      {:ok, lv, _html} =
        live(conn, ~p"/app/workspaces/#{workspace.slug}/projects/#{project.slug}")

      # Show modal
      lv
      |> element("button", "New Page")
      |> render_click()

      # Submit form
      lv
      |> form("#page-form", title: "New Test Page")
      |> render_submit()

      # Should redirect to new page
      assert_redirect(lv, ~p"/app/workspaces/#{workspace.slug}/pages/new-test-page")
    end

    test "deletes project and redirects when clicking delete", %{
      conn: conn,
      workspace: workspace,
      project: project
    } do
      {:ok, lv, _html} =
        live(conn, ~p"/app/workspaces/#{workspace.slug}/projects/#{project.slug}")

      lv
      |> element("button", "Delete Project")
      |> render_click()

      # Should redirect to workspace show page
      assert_redirect(lv, ~p"/app/workspaces/#{workspace.slug}")
    end

    test "displays project color when present", %{conn: conn, user: user} do
      workspace = workspace_fixture(user)
      project = project_fixture(user, workspace, %{color: "#FF5733"})

      {:ok, _lv, html} =
        live(conn, ~p"/app/workspaces/#{workspace.slug}/projects/#{project.slug}")

      assert html =~ "#FF5733"
      assert html =~ "Color:"
    end

    test "displays project creation date", %{conn: conn, workspace: workspace, project: project} do
      {:ok, _lv, html} =
        live(conn, ~p"/app/workspaces/#{workspace.slug}/projects/#{project.slug}")

      assert html =~ "Created:"
    end

    test "redirects when workspace doesn't exist", %{conn: conn} do
      assert {:error, {:redirect, %{to: path}}} =
               live(conn, ~p"/app/workspaces/nonexistent/projects/test")

      assert path == ~p"/app/workspaces"
    end

    test "redirects when project doesn't exist", %{conn: conn, workspace: workspace} do
      assert {:error, {:redirect, %{to: path}}} =
               live(conn, ~p"/app/workspaces/#{workspace.slug}/projects/nonexistent")

      assert path == ~p"/app/workspaces"
    end

    test "redirects when user is not a member of workspace", %{conn: conn} do
      other_user = user_fixture()
      other_workspace = workspace_fixture(other_user)
      other_project = project_fixture(other_user, other_workspace)

      assert {:error, {:redirect, %{to: path}}} =
               live(
                 conn,
                 ~p"/app/workspaces/#{other_workspace.slug}/projects/#{other_project.slug}"
               )

      assert path == ~p"/app/workspaces"
    end

    test "updates page title in real-time when page_title_changed event is received", %{
      conn: conn,
      user: user,
      workspace: workspace,
      project: project
    } do
      {:ok, page} =
        Pages.create_page(user, workspace.id, %{title: "Original Title", project_id: project.id})

      {:ok, lv, html} = live(conn, ~p"/app/workspaces/#{workspace.slug}/projects/#{project.slug}")

      assert html =~ "Original Title"

      # Simulate PubSub event
      send(lv.pid, {:page_title_changed, page.id, "Updated Title"})

      html = render(lv)
      assert html =~ "Updated Title"
      refute html =~ "Original Title"
    end

    test "reloads pages when page_visibility_changed event is received", %{
      conn: conn,
      user: user,
      workspace: workspace,
      project: project
    } do
      {:ok, page} =
        Pages.create_page(user, workspace.id, %{title: "Test Page", project_id: project.id})

      {:ok, lv, _html} =
        live(conn, ~p"/app/workspaces/#{workspace.slug}/projects/#{project.slug}")

      # Simulate PubSub event
      send(lv.pid, {:page_visibility_changed, page.id, true})

      # Page list should be reloaded
      assert render(lv) =~ "Test Page"
    end

    test "updates workspace name when workspace_updated event is received", %{
      conn: conn,
      workspace: workspace,
      project: project
    } do
      {:ok, lv, html} = live(conn, ~p"/app/workspaces/#{workspace.slug}/projects/#{project.slug}")

      assert html =~ workspace.name

      # Simulate PubSub event
      send(lv.pid, {:workspace_updated, workspace.id, "New Workspace Name"})

      html = render(lv)
      assert html =~ "New Workspace Name"
    end

    test "updates project name when project_updated event is received", %{
      conn: conn,
      workspace: workspace,
      project: project
    } do
      {:ok, lv, html} = live(conn, ~p"/app/workspaces/#{workspace.slug}/projects/#{project.slug}")

      assert html =~ project.name

      # Simulate PubSub event
      send(lv.pid, {:project_updated, project.id, "New Project Name"})

      html = render(lv)
      assert html =~ "New Project Name"
    end

    test "ignores workspace_updated event for different workspace", %{
      conn: conn,
      workspace: workspace,
      project: project
    } do
      {:ok, lv, html} = live(conn, ~p"/app/workspaces/#{workspace.slug}/projects/#{project.slug}")

      original_name = workspace.name
      assert html =~ original_name

      # Simulate PubSub event for different workspace
      send(lv.pid, {:workspace_updated, Ecto.UUID.generate(), "Other Name"})

      html = render(lv)
      assert html =~ original_name
      refute html =~ "Other Name"
    end

    test "ignores project_updated event for different project", %{
      conn: conn,
      workspace: workspace,
      project: project
    } do
      {:ok, lv, html} = live(conn, ~p"/app/workspaces/#{workspace.slug}/projects/#{project.slug}")

      original_name = project.name
      assert html =~ original_name

      # Simulate PubSub event for different project
      send(lv.pid, {:project_updated, Ecto.UUID.generate(), "Other Name"})

      html = render(lv)
      assert html =~ original_name
      refute html =~ "Other Name"
    end
  end
end
