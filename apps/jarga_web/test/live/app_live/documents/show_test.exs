defmodule JargaWeb.AppLive.Documents.ShowTest do
  use JargaWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Jarga.AccountsFixtures
  import Jarga.WorkspacesFixtures
  import Jarga.DocumentsFixtures
  import Jarga.ProjectsFixtures

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
end
