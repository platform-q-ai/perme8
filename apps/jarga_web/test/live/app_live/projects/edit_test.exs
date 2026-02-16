defmodule JargaWeb.AppLive.Projects.EditTest do
  use JargaWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Jarga.AccountsFixtures
  import Jarga.WorkspacesFixtures
  import Jarga.ProjectsFixtures

  describe "edit project page" do
    test "redirects if user is not logged in", %{conn: conn} do
      user = user_fixture()
      workspace = workspace_fixture(user)
      project = project_fixture(user, workspace)

      assert {:error, redirect} =
               live(conn, ~p"/app/workspaces/#{workspace.slug}/projects/#{project.slug}/edit")

      assert {:redirect, %{to: path, flash: flash}} = redirect
      assert path == ~p"/users/log-in"
      assert %{"error" => "You must log in to access this page."} = flash
    end
  end

  describe "edit project page (authenticated)" do
    setup %{conn: conn} do
      user = user_fixture()
      workspace = workspace_fixture(user)
      project = project_fixture(user, workspace)

      %{conn: log_in_user(conn, user), user: user, workspace: workspace, project: project}
    end

    test "renders edit project page", %{conn: conn, workspace: workspace, project: project} do
      {:ok, _lv, html} =
        live(conn, ~p"/app/workspaces/#{workspace.slug}/projects/#{project.slug}/edit")

      assert html =~ "Edit Project"
      assert html =~ project.name
    end

    test "displays breadcrumbs", %{conn: conn, workspace: workspace, project: project} do
      {:ok, _lv, html} =
        live(conn, ~p"/app/workspaces/#{workspace.slug}/projects/#{project.slug}/edit")

      assert html =~ "Home"
      assert html =~ "Workspaces"
      assert html =~ workspace.name
      assert html =~ project.name
      assert html =~ "Edit"
    end

    test "displays project form with current values", %{
      conn: conn,
      workspace: workspace,
      project: project
    } do
      {:ok, lv, html} =
        live(conn, ~p"/app/workspaces/#{workspace.slug}/projects/#{project.slug}/edit")

      assert html =~ "Name"
      assert html =~ "Description"
      assert html =~ "Color"

      # Check form has project values
      assert lv |> element("#project-form") |> has_element?()
    end

    test "updates project with valid data", %{conn: conn, workspace: workspace, project: project} do
      {:ok, lv, _html} =
        live(conn, ~p"/app/workspaces/#{workspace.slug}/projects/#{project.slug}/edit")

      lv
      |> form("#project-form", project: %{name: "Updated Project", description: "New desc"})
      |> render_submit()

      # Verify redirect back to project (slug remains unchanged)
      assert_redirect(lv, ~p"/app/workspaces/#{workspace.slug}/projects/#{project.slug}")
    end

    test "shows error with invalid data", %{conn: conn, workspace: workspace, project: project} do
      {:ok, lv, _html} =
        live(conn, ~p"/app/workspaces/#{workspace.slug}/projects/#{project.slug}/edit")

      result =
        lv
        |> form("#project-form", project: %{name: ""})
        |> render_submit()

      assert result =~ "can&#39;t be blank"
    end

    test "has cancel link that goes back to project", %{
      conn: conn,
      workspace: workspace,
      project: project
    } do
      {:ok, lv, _html} =
        live(conn, ~p"/app/workspaces/#{workspace.slug}/projects/#{project.slug}/edit")

      assert lv
             |> element("a", "Cancel")
             |> has_element?()
    end

    test "redirects when workspace doesn't exist", %{conn: conn} do
      assert {:error, {:redirect, %{to: "/app/workspaces", flash: %{"error" => _}}}} =
               live(conn, ~p"/app/workspaces/nonexistent/projects/test/edit")
    end

    test "redirects when project doesn't exist", %{conn: conn, workspace: workspace} do
      assert {:error, {:redirect, %{to: "/app/workspaces", flash: %{"error" => _}}}} =
               live(conn, ~p"/app/workspaces/#{workspace.slug}/projects/nonexistent/edit")
    end

    test "redirects when user is not a member of workspace", %{conn: conn} do
      other_user = user_fixture()
      other_workspace = workspace_fixture(other_user)
      other_project = project_fixture(other_user, other_workspace)

      assert {:error, {:redirect, %{to: "/app/workspaces", flash: %{"error" => _}}}} =
               live(
                 conn,
                 ~p"/app/workspaces/#{other_workspace.slug}/projects/#{other_project.slug}/edit"
               )
    end

    test "redirects guest who cannot edit projects", %{workspace: workspace, project: project} do
      guest = user_fixture()
      add_workspace_member_fixture(workspace.id, guest, :guest)
      guest_conn = build_conn() |> log_in_user(guest)

      assert {:error,
              {:redirect,
               %{to: "/app/workspaces", flash: %{"error" => "You are not authorized" <> _}}}} =
               live(
                 guest_conn,
                 ~p"/app/workspaces/#{workspace.slug}/projects/#{project.slug}/edit"
               )
    end
  end
end
