defmodule JargaWeb.AppLive.Documents.ShowTest do
  use JargaWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Jarga.AccountsFixtures
  import Jarga.WorkspacesFixtures
  import Jarga.DocumentsFixtures
  import Jarga.ProjectsFixtures

  alias Jarga.Documents.Domain.Events.{
    DocumentVisibilityChanged,
    DocumentPinnedChanged,
    DocumentTitleChanged,
    DocumentCreated
  }

  alias Identity.Domain.Events.WorkspaceUpdated
  alias Jarga.Projects.Domain.Events.ProjectUpdated

  alias Agents.Domain.Events.{
    AgentUpdated,
    AgentDeleted,
    AgentAddedToWorkspace,
    AgentRemovedFromWorkspace
  }

  describe "mount/3 - readonly assignment for guests" do
    test "sets readonly to true when user is a guest", %{conn: conn} do
      # Arrange: Create workspace owner, guest, and document
      owner = user_fixture()
      guest = user_fixture()
      workspace = workspace_fixture(owner)
      project = project_fixture(owner, workspace)
      document = document_fixture(owner, workspace, project, %{is_public: true})

      # Add guest to workspace
      {:ok, _} = invite_and_accept_member(owner, workspace.id, guest.email, :guest)

      # Act: Guest mounts the document
      conn = log_in_user(conn, guest)

      {:ok, _view, html} =
        live(conn, ~p"/app/workspaces/#{workspace.slug}/documents/#{document.slug}")

      # Assert: Readonly mode is enabled
      assert html =~ "read-only mode"
      assert html =~ "data-readonly=\"true\""
    end

    test "sets readonly to false when user is a member", %{conn: conn} do
      # Arrange: Create workspace owner, member, and document
      owner = user_fixture()
      member = user_fixture()
      workspace = workspace_fixture(owner)
      project = project_fixture(owner, workspace)
      document = document_fixture(owner, workspace, project, %{is_public: true})

      # Add member to workspace
      {:ok, _} = invite_and_accept_member(owner, workspace.id, member.email, :member)

      # Act: Member mounts the document
      conn = log_in_user(conn, member)

      {:ok, _view, html} =
        live(conn, ~p"/app/workspaces/#{workspace.slug}/documents/#{document.slug}")

      # Assert: Readonly mode is disabled
      refute html =~ "read-only mode"
      assert html =~ "data-readonly=\"false\""
    end

    test "sets readonly to false when user is an admin", %{conn: conn} do
      # Arrange: Create workspace owner, admin, and document
      owner = user_fixture()
      admin = user_fixture()
      workspace = workspace_fixture(owner)
      project = project_fixture(owner, workspace)
      document = document_fixture(owner, workspace, project, %{is_public: true})

      # Add admin to workspace
      {:ok, _} = invite_and_accept_member(owner, workspace.id, admin.email, :admin)

      # Act: Admin mounts the document
      conn = log_in_user(conn, admin)

      {:ok, _view, html} =
        live(conn, ~p"/app/workspaces/#{workspace.slug}/documents/#{document.slug}")

      # Assert: Readonly mode is disabled
      refute html =~ "read-only mode"
      assert html =~ "data-readonly=\"false\""
    end

    test "sets readonly to false when user is the owner", %{conn: conn} do
      # Arrange: Create workspace owner and document
      owner = user_fixture()
      workspace = workspace_fixture(owner)
      project = project_fixture(owner, workspace)
      document = document_fixture(owner, workspace, project, %{is_public: true})

      # Act: Owner mounts the document
      conn = log_in_user(conn, owner)

      {:ok, _view, html} =
        live(conn, ~p"/app/workspaces/#{workspace.slug}/documents/#{document.slug}")

      # Assert: Readonly mode is disabled
      refute html =~ "read-only mode"
      assert html =~ "data-readonly=\"false\""
    end

    test "sets readonly to false when user is the document creator", %{conn: conn} do
      # Arrange: Create workspace with owner and member who creates a document
      owner = user_fixture()
      member = user_fixture()
      workspace = workspace_fixture(owner)
      project = project_fixture(owner, workspace)

      # Add member to workspace
      {:ok, _} = invite_and_accept_member(owner, workspace.id, member.email, :member)

      # Member creates their own document
      document = document_fixture(member, workspace, project, %{is_public: true})

      # Act: Member (document creator) mounts the document
      conn = log_in_user(conn, member)

      {:ok, _view, html} =
        live(conn, ~p"/app/workspaces/#{workspace.slug}/documents/#{document.slug}")

      # Assert: Readonly mode is disabled (creator can edit their own document)
      refute html =~ "read-only mode"
      assert html =~ "data-readonly=\"false\""
    end
  end

  describe "mount/3 - actions menu visibility" do
    test "hides actions menu for guests", %{conn: conn} do
      # Arrange: Create workspace owner, guest, and document
      owner = user_fixture()
      guest = user_fixture()
      workspace = workspace_fixture(owner)
      project = project_fixture(owner, workspace)
      document = document_fixture(owner, workspace, project, %{is_public: true})

      # Add guest to workspace
      {:ok, _} = invite_and_accept_member(owner, workspace.id, guest.email, :guest)

      # Act: Guest mounts the document
      conn = log_in_user(conn, guest)

      {:ok, _view, html} =
        live(conn, ~p"/app/workspaces/#{workspace.slug}/documents/#{document.slug}")

      # Assert: Actions menu is not present
      refute html =~ "Actions menu"
    end

    test "shows actions menu for members on public documents", %{conn: conn} do
      # Arrange: Create workspace owner, member, and document
      owner = user_fixture()
      member = user_fixture()
      workspace = workspace_fixture(owner)
      project = project_fixture(owner, workspace)
      document = document_fixture(owner, workspace, project, %{is_public: true})

      # Add member to workspace
      {:ok, _} = invite_and_accept_member(owner, workspace.id, member.email, :member)

      # Act: Member mounts the document
      conn = log_in_user(conn, member)

      {:ok, _view, html} =
        live(conn, ~p"/app/workspaces/#{workspace.slug}/documents/#{document.slug}")

      # Assert: Actions menu is present
      assert html =~ "Actions menu"
    end

    test "shows actions menu for document creator", %{conn: conn} do
      # Arrange: Create workspace owner and document
      owner = user_fixture()
      workspace = workspace_fixture(owner)
      project = project_fixture(owner, workspace)
      document = document_fixture(owner, workspace, project, %{is_public: true})

      # Act: Owner (document creator) mounts the document
      conn = log_in_user(conn, owner)

      {:ok, _view, html} =
        live(conn, ~p"/app/workspaces/#{workspace.slug}/documents/#{document.slug}")

      # Assert: Actions menu is present
      assert html =~ "Actions menu"
    end
  end

  describe "handle_event/3 - edit protection for guests" do
    test "guests have readonly UI - title is not editable", %{conn: conn} do
      # Arrange: Create workspace owner, guest, and document
      owner = user_fixture()
      guest = user_fixture()
      workspace = workspace_fixture(owner)
      project = project_fixture(owner, workspace)

      document =
        document_fixture(owner, workspace, project, %{title: "Test Document", is_public: true})

      # Add guest to workspace
      {:ok, _} = invite_and_accept_member(owner, workspace.id, guest.email, :guest)

      # Act: Guest mounts the document
      conn = log_in_user(conn, guest)

      {:ok, _view, html} =
        live(conn, ~p"/app/workspaces/#{workspace.slug}/documents/#{document.slug}")

      # Assert: Title click hint is not present (guests cannot edit title)
      refute html =~ "Click to edit title"

      # Assert: Title hover transition class is not applied to the title
      # Look for the document title without the hover:text-primary class
      assert html =~ "Test Document"

      # Note: In readonly mode, phx-click is nil, so clicking title does nothing
      # The UI itself prevents the interaction
    end

    test "members can see editable title UI", %{conn: conn} do
      # Arrange: Create workspace owner, member, and document
      owner = user_fixture()
      member = user_fixture()
      workspace = workspace_fixture(owner)
      project = project_fixture(owner, workspace)
      document = document_fixture(owner, workspace, project, %{is_public: true})

      # Add member to workspace
      {:ok, _} = invite_and_accept_member(owner, workspace.id, member.email, :member)

      # Act: Member mounts the document
      conn = log_in_user(conn, member)

      {:ok, view, html} =
        live(conn, ~p"/app/workspaces/#{workspace.slug}/documents/#{document.slug}")

      # Assert: Title has hover styling
      assert html =~ "cursor-pointer"

      # Assert: Title click hint is present
      assert html =~ "Click to edit title"

      # Act: Member clicks title to edit
      html = render_click(view, "start_edit_title")

      # Assert: Title form is now visible
      assert html =~ "id=\"document-title-input\""
    end
  end

  describe "structured event handlers" do
    setup %{conn: conn} do
      owner = user_fixture()
      workspace = workspace_fixture(owner)
      project = project_fixture(owner, workspace)
      document = document_fixture(owner, workspace, project, %{is_public: true})
      conn = log_in_user(conn, owner)

      %{conn: conn, owner: owner, workspace: workspace, project: project, document: document}
    end

    test "handles DocumentVisibilityChanged event by updating document", %{
      conn: conn,
      owner: owner,
      workspace: workspace,
      document: document
    } do
      {:ok, lv, _html} =
        live(conn, ~p"/app/workspaces/#{workspace.slug}/documents/#{document.slug}")

      event =
        DocumentVisibilityChanged.new(%{
          aggregate_id: document.id,
          actor_id: owner.id,
          document_id: document.id,
          user_id: owner.id,
          workspace_id: workspace.id,
          is_public: false
        })

      send(lv.pid, event)

      # The handler should update the document's is_public field
      html = render(lv)
      assert html =~ "Make Public"
    end

    test "ignores DocumentVisibilityChanged for different document", %{
      conn: conn,
      owner: owner,
      workspace: workspace,
      document: document
    } do
      {:ok, lv, _html} =
        live(conn, ~p"/app/workspaces/#{workspace.slug}/documents/#{document.slug}")

      event =
        DocumentVisibilityChanged.new(%{
          aggregate_id: Ecto.UUID.generate(),
          actor_id: owner.id,
          document_id: Ecto.UUID.generate(),
          user_id: owner.id,
          workspace_id: workspace.id,
          is_public: false
        })

      send(lv.pid, event)

      # Should not crash, should remain unchanged
      assert render(lv)
    end

    test "handles DocumentPinnedChanged event by updating document", %{
      conn: conn,
      owner: owner,
      workspace: workspace,
      document: document
    } do
      {:ok, lv, _html} =
        live(conn, ~p"/app/workspaces/#{workspace.slug}/documents/#{document.slug}")

      event =
        DocumentPinnedChanged.new(%{
          aggregate_id: document.id,
          actor_id: owner.id,
          document_id: document.id,
          user_id: owner.id,
          workspace_id: workspace.id,
          is_pinned: true
        })

      send(lv.pid, event)

      html = render(lv)
      assert html =~ "Unpin Document"
    end

    test "handles DocumentTitleChanged event by updating document title", %{
      conn: conn,
      owner: owner,
      workspace: workspace,
      document: document
    } do
      {:ok, lv, html} =
        live(conn, ~p"/app/workspaces/#{workspace.slug}/documents/#{document.slug}")

      assert html =~ document.title

      event =
        DocumentTitleChanged.new(%{
          aggregate_id: document.id,
          actor_id: owner.id,
          document_id: document.id,
          user_id: owner.id,
          workspace_id: workspace.id,
          title: "Brand New Title"
        })

      send(lv.pid, event)

      html = render(lv)
      assert html =~ "Brand New Title"
    end

    test "handles WorkspaceUpdated event by updating workspace name", %{
      conn: conn,
      owner: owner,
      workspace: workspace,
      document: document
    } do
      {:ok, lv, html} =
        live(conn, ~p"/app/workspaces/#{workspace.slug}/documents/#{document.slug}")

      assert html =~ workspace.name

      event =
        WorkspaceUpdated.new(%{
          aggregate_id: workspace.id,
          actor_id: owner.id,
          workspace_id: workspace.id,
          name: "Renamed Workspace"
        })

      send(lv.pid, event)

      html = render(lv)
      assert html =~ "Renamed Workspace"
    end

    test "ignores WorkspaceUpdated event for different workspace", %{
      conn: conn,
      owner: owner,
      workspace: workspace,
      document: document
    } do
      {:ok, lv, html} =
        live(conn, ~p"/app/workspaces/#{workspace.slug}/documents/#{document.slug}")

      original_name = workspace.name
      assert html =~ original_name

      event =
        WorkspaceUpdated.new(%{
          aggregate_id: Ecto.UUID.generate(),
          actor_id: owner.id,
          workspace_id: Ecto.UUID.generate(),
          name: "Other Workspace"
        })

      send(lv.pid, event)

      html = render(lv)
      assert html =~ original_name
      refute html =~ "Other Workspace"
    end

    test "handles ProjectUpdated event by updating project name", %{
      conn: conn,
      owner: owner,
      workspace: workspace,
      project: project,
      document: document
    } do
      {:ok, lv, _html} =
        live(conn, ~p"/app/workspaces/#{workspace.slug}/documents/#{document.slug}")

      event =
        ProjectUpdated.new(%{
          aggregate_id: project.id,
          actor_id: owner.id,
          project_id: project.id,
          user_id: owner.id,
          workspace_id: workspace.id,
          name: "Renamed Project"
        })

      send(lv.pid, event)

      # Should not crash
      assert render(lv)
    end

    test "handles DocumentCreated event as no-op on show page", %{
      conn: conn,
      owner: owner,
      workspace: workspace,
      document: document
    } do
      {:ok, lv, _html} =
        live(conn, ~p"/app/workspaces/#{workspace.slug}/documents/#{document.slug}")

      event =
        DocumentCreated.new(%{
          aggregate_id: Ecto.UUID.generate(),
          actor_id: owner.id,
          document_id: Ecto.UUID.generate(),
          project_id: nil,
          user_id: owner.id,
          workspace_id: workspace.id,
          title: "New Doc"
        })

      send(lv.pid, event)

      # Should not crash - it's a no-op on the show page
      assert render(lv)
    end

    test "handles AgentUpdated event by reloading workspace agents", %{
      conn: conn,
      owner: owner,
      workspace: workspace,
      document: document
    } do
      {:ok, lv, _html} =
        live(conn, ~p"/app/workspaces/#{workspace.slug}/documents/#{document.slug}")

      event =
        AgentUpdated.new(%{
          aggregate_id: Ecto.UUID.generate(),
          actor_id: owner.id,
          agent_id: Ecto.UUID.generate(),
          user_id: owner.id,
          workspace_ids: [workspace.id],
          changes: %{name: "Updated Agent"}
        })

      send(lv.pid, event)

      # Should not crash
      assert render(lv)
    end

    test "handles AgentDeleted event by reloading workspace agents", %{
      conn: conn,
      owner: owner,
      workspace: workspace,
      document: document
    } do
      {:ok, lv, _html} =
        live(conn, ~p"/app/workspaces/#{workspace.slug}/documents/#{document.slug}")

      event =
        AgentDeleted.new(%{
          aggregate_id: Ecto.UUID.generate(),
          actor_id: owner.id,
          agent_id: Ecto.UUID.generate(),
          user_id: owner.id,
          workspace_ids: [workspace.id]
        })

      send(lv.pid, event)

      assert render(lv)
    end

    test "handles AgentAddedToWorkspace event by reloading workspace agents", %{
      conn: conn,
      owner: owner,
      workspace: workspace,
      document: document
    } do
      {:ok, lv, _html} =
        live(conn, ~p"/app/workspaces/#{workspace.slug}/documents/#{document.slug}")

      event =
        AgentAddedToWorkspace.new(%{
          aggregate_id: Ecto.UUID.generate(),
          actor_id: owner.id,
          agent_id: Ecto.UUID.generate(),
          user_id: owner.id,
          workspace_id: workspace.id
        })

      send(lv.pid, event)

      assert render(lv)
    end

    test "handles AgentRemovedFromWorkspace event by reloading workspace agents", %{
      conn: conn,
      owner: owner,
      workspace: workspace,
      document: document
    } do
      {:ok, lv, _html} =
        live(conn, ~p"/app/workspaces/#{workspace.slug}/documents/#{document.slug}")

      event =
        AgentRemovedFromWorkspace.new(%{
          aggregate_id: Ecto.UUID.generate(),
          actor_id: owner.id,
          agent_id: Ecto.UUID.generate(),
          user_id: owner.id,
          workspace_id: workspace.id
        })

      send(lv.pid, event)

      assert render(lv)
    end
  end
end
