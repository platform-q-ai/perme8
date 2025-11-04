defmodule JargaWeb.AppLive.WorkspacesTest do
  use JargaWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Jarga.AccountsFixtures
  import Jarga.WorkspacesFixtures
  import Jarga.ProjectsFixtures

  describe "workspaces index page" do
    test "redirects if user is not logged in", %{conn: conn} do
      assert {:error, redirect} = live(conn, ~p"/app/workspaces")

      assert {:redirect, %{to: path, flash: flash}} = redirect
      assert path == ~p"/users/log-in"
      assert %{"error" => "You must log in to access this page."} = flash
    end
  end

  describe "workspaces index page (authenticated)" do
    setup %{conn: conn} do
      user = user_fixture()
      %{conn: log_in_user(conn, user), user: user}
    end

    test "renders workspaces index page", %{conn: conn} do
      {:ok, _lv, html} = live(conn, ~p"/app/workspaces")

      assert html =~ "Workspaces"
    end

    test "displays empty state when user has no workspaces", %{conn: conn} do
      {:ok, _lv, html} = live(conn, ~p"/app/workspaces")

      assert html =~ "No workspaces yet"
    end

    test "displays list of user's workspaces", %{conn: conn, user: user} do
      workspace1 = workspace_fixture(user, %{name: "Personal Workspace"})
      workspace2 = workspace_fixture(user, %{name: "Team Workspace"})

      {:ok, _lv, html} = live(conn, ~p"/app/workspaces")

      assert html =~ "Personal Workspace"
      assert html =~ "Team Workspace"
      assert html =~ workspace1.id
      assert html =~ workspace2.id
    end

    test "does not display other users' workspaces", %{conn: conn, user: user} do
      _my_workspace = workspace_fixture(user, %{name: "My Workspace"})

      other_user = user_fixture()
      _other_workspace = workspace_fixture(other_user, %{name: "Other Workspace"})

      {:ok, _lv, html} = live(conn, ~p"/app/workspaces")

      assert html =~ "My Workspace"
      refute html =~ "Other Workspace"
    end

    test "displays workspace descriptions", %{conn: conn, user: user} do
      _workspace = workspace_fixture(user, %{
        name: "Test Workspace",
        description: "This is a test description"
      })

      {:ok, _lv, html} = live(conn, ~p"/app/workspaces")

      assert html =~ "This is a test description"
    end

    test "has a new workspace button", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/app/workspaces")

      assert lv |> element("a", "New Workspace") |> has_element?()
    end

    test "navigates to new workspace form when clicking new workspace button", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/app/workspaces")

      assert {:error, {:live_redirect, %{to: redirect_path}}} =
               lv |> element("a", "New Workspace") |> render_click()

      assert redirect_path == ~p"/app/workspaces/new"
    end
  end

  describe "new workspace page (authenticated)" do
    setup %{conn: conn} do
      user = user_fixture()
      %{conn: log_in_user(conn, user), user: user}
    end

    test "renders new workspace form", %{conn: conn} do
      {:ok, _lv, html} = live(conn, ~p"/app/workspaces/new")

      assert html =~ "New Workspace"
      assert html =~ "Name"
    end

    test "creates workspace with valid data", %{conn: conn, user: _user} do
      {:ok, lv, _html} = live(conn, ~p"/app/workspaces/new")

      result = lv
             |> form("#workspace-form", workspace: %{name: "New Test Workspace"})
             |> render_submit()

      # Should redirect to index with success flash
      assert {:error, {:live_redirect, %{to: path, flash: _flash}}} = result
      assert path == ~p"/app/workspaces"

      # Verify workspace was created by checking index page
      {:ok, _index_lv, html} = live(conn, ~p"/app/workspaces")
      assert html =~ "New Test Workspace"
    end

    test "creates workspace with full data", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/app/workspaces/new")

      assert lv
             |> form("#workspace-form", workspace: %{
               name: "Full Workspace",
               description: "A complete workspace",
               color: "#FF5733"
             })
             |> render_submit()

      assert_redirected(lv, ~p"/app/workspaces")

      # Verify workspace was created with all attributes
      {:ok, _lv, html} = live(conn, ~p"/app/workspaces")
      assert html =~ "Full Workspace"
      assert html =~ "A complete workspace"
    end

    test "displays validation errors for invalid data", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/app/workspaces/new")

      html =
        lv
        |> form("#workspace-form", workspace: %{name: ""})
        |> render_submit()

      assert html =~ "can&#39;t be blank"
    end

    test "has a cancel button that returns to index", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/app/workspaces/new")

      assert lv |> element("a", "Cancel") |> has_element?()
    end
  end

  describe "workspace show page (authenticated)" do
    setup %{conn: conn} do
      user = user_fixture()
      workspace = workspace_fixture(user, %{name: "Test Workspace"})
      %{conn: log_in_user(conn, user), user: user, workspace: workspace}
    end

    test "renders workspace show page", %{conn: conn, workspace: workspace} do
      {:ok, _lv, html} = live(conn, ~p"/app/workspaces/#{workspace.id}")

      assert html =~ "Test Workspace"
      assert html =~ "Projects"
    end

    test "displays empty state when workspace has no projects", %{conn: conn, workspace: workspace} do
      {:ok, _lv, html} = live(conn, ~p"/app/workspaces/#{workspace.id}")

      assert html =~ "No projects yet"
    end

    test "displays list of workspace projects", %{conn: conn, user: user, workspace: workspace} do
      project1 = project_fixture(user, workspace, %{name: "Project Alpha"})
      project2 = project_fixture(user, workspace, %{name: "Project Beta"})

      {:ok, _lv, html} = live(conn, ~p"/app/workspaces/#{workspace.id}")

      assert html =~ "Project Alpha"
      assert html =~ "Project Beta"
      assert html =~ project1.id
      assert html =~ project2.id
    end

    test "does not display projects from other workspaces", %{conn: conn, user: user, workspace: workspace} do
      other_workspace = workspace_fixture(user, %{name: "Other Workspace"})
      _my_project = project_fixture(user, workspace, %{name: "My Project"})
      _other_project = project_fixture(user, other_workspace, %{name: "Other Project"})

      {:ok, _lv, html} = live(conn, ~p"/app/workspaces/#{workspace.id}")

      assert html =~ "My Project"
      refute html =~ "Other Project"
    end

    test "displays project descriptions", %{conn: conn, user: user, workspace: workspace} do
      _project = project_fixture(user, workspace, %{
        name: "Test Project",
        description: "This is a test project description"
      })

      {:ok, _lv, html} = live(conn, ~p"/app/workspaces/#{workspace.id}")

      assert html =~ "This is a test project description"
    end

    test "has a new project button", %{conn: conn, workspace: workspace} do
      {:ok, lv, _html} = live(conn, ~p"/app/workspaces/#{workspace.id}")

      assert lv |> element("button", "New Project") |> has_element?()
    end

    test "opens new project modal when clicking new project button", %{conn: conn, workspace: workspace} do
      {:ok, lv, _html} = live(conn, ~p"/app/workspaces/#{workspace.id}")

      html = lv |> element("button", "New Project") |> render_click()

      assert html =~ "Create New Project"
      assert html =~ "project-form"
    end

    test "creates project with valid data", %{conn: conn, user: user, workspace: workspace} do
      {:ok, lv, _html} = live(conn, ~p"/app/workspaces/#{workspace.id}")

      # Open the modal
      lv |> element("button", "New Project") |> render_click()

      # Submit the form
      lv
      |> form("#project-form", project: %{name: "New Test Project"})
      |> render_submit()

      # Verify project appears in the list
      html = render(lv)
      assert html =~ "New Test Project"
      assert html =~ "Project created successfully"

      # Verify project was created in database
      projects = Jarga.Projects.list_projects_for_workspace(user, workspace.id)
      assert Enum.any?(projects, fn p -> p.name == "New Test Project" end)
    end

    test "creates project with full data", %{conn: conn, workspace: workspace} do
      {:ok, lv, _html} = live(conn, ~p"/app/workspaces/#{workspace.id}")

      # Open the modal
      lv |> element("button", "New Project") |> render_click()

      # Submit the form with full data
      lv
      |> form("#project-form", project: %{
        name: "Full Project",
        description: "A complete project",
        color: "#10B981"
      })
      |> render_submit()

      # Verify project appears with all attributes
      html = render(lv)
      assert html =~ "Full Project"
      assert html =~ "A complete project"
    end

    test "displays validation errors for invalid data", %{conn: conn, workspace: workspace} do
      {:ok, lv, _html} = live(conn, ~p"/app/workspaces/#{workspace.id}")

      # Open the modal
      lv |> element("button", "New Project") |> render_click()

      # Submit with invalid data
      html =
        lv
        |> form("#project-form", project: %{name: ""})
        |> render_submit()

      assert html =~ "can&#39;t be blank"
    end

    test "can close the new project modal", %{conn: conn, workspace: workspace} do
      {:ok, lv, _html} = live(conn, ~p"/app/workspaces/#{workspace.id}")

      # Open the modal
      html = lv |> element("button", "New Project") |> render_click()
      assert html =~ "Create New Project"

      # Close the modal
      html = lv |> element("button", "Cancel") |> render_click()
      refute html =~ "Create New Project"
    end

    test "redirects if user is not logged in", %{workspace: workspace} do
      conn = build_conn()
      assert {:error, redirect} = live(conn, ~p"/app/workspaces/#{workspace.id}")

      assert {:redirect, %{to: path, flash: flash}} = redirect
      assert path == ~p"/users/log-in"
      assert %{"error" => "You must log in to access this page."} = flash
    end

    test "redirects with error when user is not a member of workspace" do
      user = user_fixture()
      other_user = user_fixture()
      workspace = workspace_fixture(other_user)
      conn = build_conn() |> log_in_user(user)

      {:error, {:live_redirect, %{to: path, flash: flash}}} =
        live(conn, ~p"/app/workspaces/#{workspace.id}")

      assert path == ~p"/app/workspaces"
      assert %{"error" => "You don't have access to this workspace"} = flash
    end

    test "redirects with error when workspace does not exist" do
      user = user_fixture()
      conn = build_conn() |> log_in_user(user)
      non_existent_id = Ecto.UUID.generate()

      {:error, {:live_redirect, %{to: path, flash: flash}}} =
        live(conn, ~p"/app/workspaces/#{non_existent_id}")

      assert path == ~p"/app/workspaces"
      assert %{"error" => "Workspace not found"} = flash
    end
  end

  describe "workspace edit page (authenticated)" do
    setup %{conn: conn} do
      user = user_fixture()
      workspace = workspace_fixture(user, %{name: "Test Workspace", description: "Test Description"})
      %{conn: log_in_user(conn, user), user: user, workspace: workspace}
    end

    test "renders edit workspace form", %{conn: conn, workspace: workspace} do
      {:ok, _lv, html} = live(conn, ~p"/app/workspaces/#{workspace.id}/edit")

      assert html =~ "Edit Workspace"
      assert html =~ "Test Workspace"
      assert html =~ "Test Description"
    end

    test "updates workspace with valid data", %{conn: conn, workspace: workspace} do
      {:ok, lv, _html} = live(conn, ~p"/app/workspaces/#{workspace.id}/edit")

      result =
        lv
        |> form("#workspace-form", workspace: %{
          name: "Updated Workspace",
          description: "Updated Description"
        })
        |> render_submit()

      assert {:error, {:live_redirect, %{to: path, flash: _flash}}} = result
      assert path == ~p"/app/workspaces/#{workspace.id}"

      # Verify workspace was updated
      {:ok, _lv, html} = live(conn, ~p"/app/workspaces/#{workspace.id}")
      assert html =~ "Updated Workspace"
      assert html =~ "Updated Description"
    end

    test "displays validation errors for invalid data", %{conn: conn, workspace: workspace} do
      {:ok, lv, _html} = live(conn, ~p"/app/workspaces/#{workspace.id}/edit")

      html =
        lv
        |> form("#workspace-form", workspace: %{name: ""})
        |> render_submit()

      assert html =~ "can&#39;t be blank"
    end

    test "has a cancel button that returns to workspace show", %{conn: conn, workspace: workspace} do
      {:ok, lv, _html} = live(conn, ~p"/app/workspaces/#{workspace.id}/edit")

      assert lv |> element("a", "Cancel") |> has_element?()
    end

    test "redirects if user is not logged in", %{workspace: workspace} do
      conn = build_conn()
      assert {:error, redirect} = live(conn, ~p"/app/workspaces/#{workspace.id}/edit")

      assert {:redirect, %{to: path, flash: flash}} = redirect
      assert path == ~p"/users/log-in"
      assert %{"error" => "You must log in to access this page."} = flash
    end

    test "raises when user is not a member of workspace" do
      user = user_fixture()
      other_user = user_fixture()
      workspace = workspace_fixture(other_user)
      conn = build_conn() |> log_in_user(user)

      assert_raise Ecto.NoResultsError, fn ->
        live(conn, ~p"/app/workspaces/#{workspace.id}/edit")
      end
    end
  end

  describe "workspace deletion" do
    setup %{conn: conn} do
      user = user_fixture()
      workspace = workspace_fixture(user, %{name: "Test Workspace"})
      %{conn: log_in_user(conn, user), user: user, workspace: workspace}
    end

    test "deletes workspace from show page", %{conn: conn, user: user, workspace: workspace} do
      {:ok, lv, _html} = live(conn, ~p"/app/workspaces/#{workspace.id}")

      # Click delete button
      result = lv |> element("button", "Delete Workspace") |> render_click()

      assert {:error, {:live_redirect, %{to: path, flash: _flash}}} = result
      assert path == ~p"/app/workspaces"

      # Verify workspace is deleted
      assert Jarga.Workspaces.list_workspaces_for_user(user) == []
    end

    test "deletes workspace and its projects", %{conn: conn, user: user, workspace: workspace} do
      project = project_fixture(user, workspace)

      {:ok, lv, _html} = live(conn, ~p"/app/workspaces/#{workspace.id}")

      # Click delete button
      lv |> element("button", "Delete Workspace") |> render_click()

      # Verify project is also deleted
      assert Jarga.Repo.get(Jarga.Projects.Project, project.id) == nil
    end

    test "shows delete confirmation", %{conn: conn, workspace: workspace} do
      {:ok, lv, _html} = live(conn, ~p"/app/workspaces/#{workspace.id}")

      html = render(lv)
      assert html =~ "Delete Workspace"
    end
  end
end
