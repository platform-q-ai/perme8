defmodule JargaWeb.AppLive.Projects.ShowTest do
  use JargaWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Jarga.AccountsFixtures
  import Jarga.WorkspacesFixtures
  import Jarga.ProjectsFixtures

  alias Jarga.Documents

  alias Jarga.Documents.Domain.Events.{
    DocumentVisibilityChanged,
    DocumentTitleChanged,
    DocumentPinnedChanged,
    DocumentCreated,
    DocumentDeleted
  }

  alias Identity.Domain.Events.WorkspaceUpdated
  alias Jarga.Projects.Domain.Events.{ProjectUpdated, ProjectDeleted}

  alias Agents.Domain.Events.{
    AgentUpdated,
    AgentDeleted,
    AgentAddedToWorkspace,
    AgentRemovedFromWorkspace
  }

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

    test "displays empty state when no documents", %{
      conn: conn,
      workspace: workspace,
      project: project
    } do
      {:ok, _lv, html} =
        live(conn, ~p"/app/workspaces/#{workspace.slug}/projects/#{project.slug}")

      assert html =~ "No documents yet"
      assert html =~ "Create your first document for this project"
    end

    test "displays documents when they exist", %{
      conn: conn,
      user: user,
      workspace: workspace,
      project: project
    } do
      {:ok, document1} =
        Documents.create_document(user, workspace.id, %{
          title: "Document One",
          project_id: project.id
        })

      {:ok, document2} =
        Documents.create_document(user, workspace.id, %{
          title: "Document Two",
          project_id: project.id
        })

      {:ok, _lv, html} =
        live(conn, ~p"/app/workspaces/#{workspace.slug}/projects/#{project.slug}")

      refute html =~ "No documents yet"
      assert html =~ "Document One"
      assert html =~ "Document Two"
      assert html =~ document1.id
      assert html =~ document2.id
    end

    test "shows pinned badge for pinned pages", %{
      conn: conn,
      user: user,
      workspace: workspace,
      project: project
    } do
      {:ok, document} =
        Documents.create_document(user, workspace.id, %{
          title: "Pinned Document",
          project_id: project.id,
          is_pinned: true
        })

      {:ok, _lv, html} =
        live(conn, ~p"/app/workspaces/#{workspace.slug}/projects/#{project.slug}")

      assert html =~ "Pinned"
      assert html =~ document.id
    end

    test "displays new document button", %{conn: conn, workspace: workspace, project: project} do
      {:ok, lv, _html} =
        live(conn, ~p"/app/workspaces/#{workspace.slug}/projects/#{project.slug}")

      assert lv |> element("button", "New Document") |> has_element?()
    end

    test "shows document modal when clicking new document button", %{
      conn: conn,
      workspace: workspace,
      project: project
    } do
      {:ok, lv, _html} =
        live(conn, ~p"/app/workspaces/#{workspace.slug}/projects/#{project.slug}")

      refute render(lv) =~ "Create New Document"

      html =
        lv
        |> element("button", "New Document")
        |> render_click()

      assert html =~ "Create New Document"
      assert html =~ "modal-open"
    end

    test "hides document modal when clicking cancel", %{
      conn: conn,
      workspace: workspace,
      project: project
    } do
      {:ok, lv, _html} =
        live(conn, ~p"/app/workspaces/#{workspace.slug}/projects/#{project.slug}")

      # Show modal
      lv
      |> element("button", "New Document")
      |> render_click()

      # Hide modal
      html =
        lv
        |> element("button", "Cancel")
        |> render_click()

      refute html =~ "Create New Document"
      refute html =~ "modal-open"
    end

    test "creates document and redirects when submitting modal", %{
      conn: conn,
      workspace: workspace,
      project: project
    } do
      {:ok, lv, _html} =
        live(conn, ~p"/app/workspaces/#{workspace.slug}/projects/#{project.slug}")

      # Show modal
      lv
      |> element("button", "New Document")
      |> render_click()

      # Submit form
      lv
      |> form("#document-form", "document-form": %{title: "New Test Document"})
      |> render_submit()

      # Should redirect to new page
      assert_redirect(lv, ~p"/app/workspaces/#{workspace.slug}/documents/new-test-document")
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

    test "updates document title in real-time when DocumentTitleChanged event is received", %{
      conn: conn,
      user: user,
      workspace: workspace,
      project: project
    } do
      {:ok, document} =
        Documents.create_document(user, workspace.id, %{
          title: "Original Title",
          project_id: project.id
        })

      {:ok, lv, html} = live(conn, ~p"/app/workspaces/#{workspace.slug}/projects/#{project.slug}")

      assert html =~ "Original Title"

      # Send structured event
      event =
        DocumentTitleChanged.new(%{
          aggregate_id: document.id,
          actor_id: user.id,
          document_id: document.id,
          user_id: user.id,
          workspace_id: workspace.id,
          title: "Updated Title"
        })

      send(lv.pid, event)

      html = render(lv)
      assert html =~ "Updated Title"
      refute html =~ "Original Title"
    end

    test "reloads documents when DocumentVisibilityChanged event is received", %{
      conn: conn,
      user: user,
      workspace: workspace,
      project: project
    } do
      {:ok, _document} =
        Documents.create_document(user, workspace.id, %{
          title: "Test Document",
          project_id: project.id
        })

      {:ok, lv, _html} =
        live(conn, ~p"/app/workspaces/#{workspace.slug}/projects/#{project.slug}")

      # Send structured event
      event =
        DocumentVisibilityChanged.new(%{
          aggregate_id: Ecto.UUID.generate(),
          actor_id: user.id,
          document_id: Ecto.UUID.generate(),
          user_id: user.id,
          workspace_id: workspace.id,
          is_public: true
        })

      send(lv.pid, event)

      # Page list should be reloaded
      assert render(lv) =~ "Test Document"
    end

    test "updates workspace name when WorkspaceUpdated event is received", %{
      conn: conn,
      user: user,
      workspace: workspace,
      project: project
    } do
      {:ok, lv, html} = live(conn, ~p"/app/workspaces/#{workspace.slug}/projects/#{project.slug}")

      assert html =~ workspace.name

      # Send structured event
      event =
        WorkspaceUpdated.new(%{
          aggregate_id: workspace.id,
          actor_id: user.id,
          workspace_id: workspace.id,
          name: "New Workspace Name"
        })

      send(lv.pid, event)

      html = render(lv)
      assert html =~ "New Workspace Name"
    end

    test "updates project name when ProjectUpdated event is received", %{
      conn: conn,
      user: user,
      workspace: workspace,
      project: project
    } do
      {:ok, lv, html} = live(conn, ~p"/app/workspaces/#{workspace.slug}/projects/#{project.slug}")

      assert html =~ project.name

      # Send structured event
      event =
        ProjectUpdated.new(%{
          aggregate_id: project.id,
          actor_id: user.id,
          project_id: project.id,
          user_id: user.id,
          workspace_id: workspace.id,
          name: "New Project Name"
        })

      send(lv.pid, event)

      html = render(lv)
      assert html =~ "New Project Name"
    end

    test "ignores WorkspaceUpdated event for different workspace", %{
      conn: conn,
      user: user,
      workspace: workspace,
      project: project
    } do
      {:ok, lv, html} = live(conn, ~p"/app/workspaces/#{workspace.slug}/projects/#{project.slug}")

      original_name = workspace.name
      assert html =~ original_name

      # Send structured event for different workspace
      other_workspace_id = Ecto.UUID.generate()

      event =
        WorkspaceUpdated.new(%{
          aggregate_id: other_workspace_id,
          actor_id: user.id,
          workspace_id: other_workspace_id,
          name: "Other Name"
        })

      send(lv.pid, event)

      html = render(lv)
      assert html =~ original_name
      refute html =~ "Other Name"
    end

    test "ignores ProjectUpdated event for different project", %{
      conn: conn,
      user: user,
      workspace: workspace,
      project: project
    } do
      {:ok, lv, html} = live(conn, ~p"/app/workspaces/#{workspace.slug}/projects/#{project.slug}")

      original_name = project.name
      assert html =~ original_name

      # Send structured event for different project
      other_project_id = Ecto.UUID.generate()

      event =
        ProjectUpdated.new(%{
          aggregate_id: other_project_id,
          actor_id: user.id,
          project_id: other_project_id,
          user_id: user.id,
          workspace_id: workspace.id,
          name: "Other Name"
        })

      send(lv.pid, event)

      html = render(lv)
      assert html =~ original_name
      refute html =~ "Other Name"
    end

    test "handles DocumentPinnedChanged event by updating pinned status", %{
      conn: conn,
      user: user,
      workspace: workspace,
      project: project
    } do
      {:ok, document} =
        Documents.create_document(user, workspace.id, %{
          title: "Test Document",
          project_id: project.id,
          is_pinned: false
        })

      {:ok, lv, html} =
        live(conn, ~p"/app/workspaces/#{workspace.slug}/projects/#{project.slug}")

      assert html =~ "Test Document"
      refute html =~ "Pinned"

      event =
        DocumentPinnedChanged.new(%{
          aggregate_id: document.id,
          actor_id: user.id,
          document_id: document.id,
          user_id: user.id,
          workspace_id: workspace.id,
          is_pinned: true
        })

      send(lv.pid, event)

      html = render(lv)
      assert html =~ "Pinned"
    end

    test "handles DocumentCreated event by adding document to list", %{
      conn: conn,
      user: user,
      workspace: workspace,
      project: project
    } do
      {:ok, lv, html} =
        live(conn, ~p"/app/workspaces/#{workspace.slug}/projects/#{project.slug}")

      assert html =~ "No documents yet"

      # Create a document in the DB first (event handler will fetch it)
      {:ok, document} =
        Documents.create_document(user, workspace.id, %{
          title: "Newly Created Doc",
          project_id: project.id
        })

      # Send structured event
      event =
        DocumentCreated.new(%{
          aggregate_id: document.id,
          actor_id: user.id,
          document_id: document.id,
          project_id: project.id,
          user_id: user.id,
          workspace_id: workspace.id,
          title: "Newly Created Doc"
        })

      send(lv.pid, event)

      html = render(lv)
      assert html =~ "Newly Created Doc"
    end

    test "ignores DocumentCreated event for different project", %{
      conn: conn,
      user: user,
      workspace: workspace,
      project: project
    } do
      {:ok, lv, html} =
        live(conn, ~p"/app/workspaces/#{workspace.slug}/projects/#{project.slug}")

      assert html =~ "No documents yet"

      other_project_id = Ecto.UUID.generate()

      event =
        DocumentCreated.new(%{
          aggregate_id: Ecto.UUID.generate(),
          actor_id: user.id,
          document_id: Ecto.UUID.generate(),
          project_id: other_project_id,
          user_id: user.id,
          workspace_id: workspace.id,
          title: "Other Project Doc"
        })

      send(lv.pid, event)

      html = render(lv)
      assert html =~ "No documents yet"
    end

    test "handles DocumentDeleted event by removing document from list", %{
      conn: conn,
      user: user,
      workspace: workspace,
      project: project
    } do
      {:ok, document} =
        Documents.create_document(user, workspace.id, %{
          title: "To Be Deleted",
          project_id: project.id
        })

      {:ok, lv, html} =
        live(conn, ~p"/app/workspaces/#{workspace.slug}/projects/#{project.slug}")

      assert html =~ "To Be Deleted"

      event =
        DocumentDeleted.new(%{
          aggregate_id: document.id,
          actor_id: user.id,
          document_id: document.id,
          user_id: user.id,
          workspace_id: workspace.id
        })

      send(lv.pid, event)

      html = render(lv)
      refute html =~ "To Be Deleted"
    end

    test "handles ProjectDeleted event by redirecting when current project is deleted", %{
      conn: conn,
      user: user,
      workspace: workspace,
      project: project
    } do
      {:ok, lv, _html} =
        live(conn, ~p"/app/workspaces/#{workspace.slug}/projects/#{project.slug}")

      event =
        ProjectDeleted.new(%{
          aggregate_id: project.id,
          actor_id: user.id,
          project_id: project.id,
          user_id: user.id,
          workspace_id: workspace.id
        })

      send(lv.pid, event)

      assert_redirect(lv, ~p"/app/workspaces/#{workspace.slug}")
    end

    test "ignores ProjectDeleted event for different project", %{
      conn: conn,
      user: user,
      workspace: workspace,
      project: project
    } do
      {:ok, lv, _html} =
        live(conn, ~p"/app/workspaces/#{workspace.slug}/projects/#{project.slug}")

      other_project_id = Ecto.UUID.generate()

      event =
        ProjectDeleted.new(%{
          aggregate_id: other_project_id,
          actor_id: user.id,
          project_id: other_project_id,
          user_id: user.id,
          workspace_id: workspace.id
        })

      send(lv.pid, event)

      # Should not redirect, page should still render
      assert render(lv)
    end

    test "handles AgentUpdated event by reloading workspace agents", %{
      conn: conn,
      user: user,
      workspace: workspace,
      project: project
    } do
      {:ok, lv, _html} =
        live(conn, ~p"/app/workspaces/#{workspace.slug}/projects/#{project.slug}")

      event =
        AgentUpdated.new(%{
          aggregate_id: Ecto.UUID.generate(),
          actor_id: user.id,
          agent_id: Ecto.UUID.generate(),
          user_id: user.id,
          workspace_ids: [workspace.id],
          changes: %{name: "Updated Agent"}
        })

      send(lv.pid, event)
      assert render(lv)
    end

    test "handles AgentDeleted event by reloading workspace agents", %{
      conn: conn,
      user: user,
      workspace: workspace,
      project: project
    } do
      {:ok, lv, _html} =
        live(conn, ~p"/app/workspaces/#{workspace.slug}/projects/#{project.slug}")

      event =
        AgentDeleted.new(%{
          aggregate_id: Ecto.UUID.generate(),
          actor_id: user.id,
          agent_id: Ecto.UUID.generate(),
          user_id: user.id,
          workspace_ids: [workspace.id]
        })

      send(lv.pid, event)
      assert render(lv)
    end

    test "handles AgentAddedToWorkspace event by reloading workspace agents", %{
      conn: conn,
      user: user,
      workspace: workspace,
      project: project
    } do
      {:ok, lv, _html} =
        live(conn, ~p"/app/workspaces/#{workspace.slug}/projects/#{project.slug}")

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

    test "handles AgentRemovedFromWorkspace event by reloading workspace agents", %{
      conn: conn,
      user: user,
      workspace: workspace,
      project: project
    } do
      {:ok, lv, _html} =
        live(conn, ~p"/app/workspaces/#{workspace.slug}/projects/#{project.slug}")

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
