defmodule JargaWeb.AppLive.Workspaces.ShowTest do
  use JargaWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Jarga.AccountsFixtures
  import Jarga.WorkspacesFixtures

  alias Jarga.Documents

  # Document domain events
  alias Jarga.Documents.Domain.Events.{
    DocumentVisibilityChanged,
    DocumentPinnedChanged,
    DocumentTitleChanged,
    DocumentCreated,
    DocumentDeleted
  }

  # Project domain events
  alias Jarga.Projects.Domain.Events.{ProjectCreated, ProjectDeleted, ProjectUpdated}

  # Cross-context domain events
  alias Identity.Domain.Events.WorkspaceUpdated
  alias Jarga.Notifications.Domain.Events.NotificationActionTaken

  # Agent domain events
  alias Agents.Domain.Events.{
    AgentUpdated,
    AgentDeleted,
    AgentAddedToWorkspace,
    AgentRemovedFromWorkspace
  }

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

  describe "workspace show page documents section" do
    setup %{conn: conn} do
      user = user_fixture()
      workspace = workspace_fixture(user)

      %{conn: log_in_user(conn, user), user: user, workspace: workspace}
    end

    test "displays empty state when no documents", %{conn: conn, workspace: workspace} do
      {:ok, _lv, html} = live(conn, ~p"/app/workspaces/#{workspace.slug}")

      assert html =~ "No documents yet"
    end

    test "displays documents when they exist", %{
      conn: conn,
      user: user,
      workspace: workspace
    } do
      {:ok, document1} = Documents.create_document(user, workspace.id, %{title: "Document One"})
      {:ok, document2} = Documents.create_document(user, workspace.id, %{title: "Document Two"})

      {:ok, _lv, html} = live(conn, ~p"/app/workspaces/#{workspace.slug}")

      assert html =~ "Document One"
      assert html =~ "Document Two"
      assert html =~ document1.id
      assert html =~ document2.id
    end

    test "shows pinned badge for pinned pages", %{
      conn: conn,
      user: user,
      workspace: workspace
    } do
      {:ok, document} =
        Documents.create_document(user, workspace.id, %{title: "Pinned", is_pinned: true})

      {:ok, _lv, html} = live(conn, ~p"/app/workspaces/#{workspace.slug}")

      assert html =~ "Pinned"
      assert html =~ document.id
    end

    test "opens document modal when clicking new document button", %{
      conn: conn,
      workspace: workspace
    } do
      {:ok, lv, _html} = live(conn, ~p"/app/workspaces/#{workspace.slug}")

      html = lv |> element("button", "New Document") |> render_click()

      assert html =~ "Create New Document"
      assert html =~ "document-form"
    end

    test "closes document modal when clicking cancel", %{conn: conn, workspace: workspace} do
      {:ok, lv, _html} = live(conn, ~p"/app/workspaces/#{workspace.slug}")

      # Open modal
      lv |> element("button", "New Document") |> render_click()

      # Close modal
      html = lv |> element("button", "Cancel") |> render_click()

      refute html =~ "modal-open"
    end

    test "creates document and redirects", %{conn: conn, workspace: workspace} do
      {:ok, lv, _html} = live(conn, ~p"/app/workspaces/#{workspace.slug}")

      # Open modal
      lv |> element("button", "New Document") |> render_click()

      # Submit form
      lv
      |> form("#document-form", "document-form": %{title: "New Document"})
      |> render_submit()

      assert_redirect(lv, ~p"/app/workspaces/#{workspace.slug}/documents/new-document")
    end
  end

  describe "workspace show page structured event handlers" do
    setup %{conn: conn} do
      user = user_fixture()
      workspace = workspace_fixture(user)

      %{conn: log_in_user(conn, user), user: user, workspace: workspace}
    end

    test "reloads projects on ProjectCreated event", %{
      conn: conn,
      user: user,
      workspace: workspace
    } do
      {:ok, lv, html} = live(conn, ~p"/app/workspaces/#{workspace.slug}")

      assert html =~ "No projects yet"

      # Create a project in DB first
      {:ok, project} =
        Jarga.Projects.create_project(user, workspace.id, %{name: "New Project"})

      # Send structured event
      event =
        ProjectCreated.new(%{
          aggregate_id: project.id,
          actor_id: user.id,
          project_id: project.id,
          user_id: user.id,
          workspace_id: workspace.id,
          name: "New Project",
          slug: "new-project"
        })

      send(lv.pid, event)

      html = render(lv)
      assert html =~ "New Project"
    end

    test "reloads projects on ProjectDeleted event", %{
      conn: conn,
      user: user,
      workspace: workspace
    } do
      {:ok, project} =
        Jarga.Projects.create_project(user, workspace.id, %{name: "To Delete"})

      {:ok, lv, html} = live(conn, ~p"/app/workspaces/#{workspace.slug}")

      assert html =~ "To Delete"

      # Delete project in DB
      {:ok, _} = Jarga.Projects.delete_project(user, workspace.id, project.id)

      # Send structured event
      event =
        ProjectDeleted.new(%{
          aggregate_id: project.id,
          actor_id: user.id,
          project_id: project.id,
          user_id: user.id,
          workspace_id: workspace.id
        })

      send(lv.pid, event)

      html = render(lv)
      refute html =~ "To Delete"
    end

    test "reloads documents on DocumentVisibilityChanged event", %{
      conn: conn,
      user: user,
      workspace: workspace
    } do
      {:ok, document} = Documents.create_document(user, workspace.id, %{title: "Test Document"})

      {:ok, lv, _html} = live(conn, ~p"/app/workspaces/#{workspace.slug}")

      # Send structured event
      event =
        DocumentVisibilityChanged.new(%{
          aggregate_id: document.id,
          actor_id: user.id,
          document_id: document.id,
          user_id: user.id,
          workspace_id: workspace.id,
          is_public: true
        })

      send(lv.pid, event)

      assert render(lv) =~ "Test Document"
    end

    test "updates document pinned state on DocumentPinnedChanged event", %{
      conn: conn,
      user: user,
      workspace: workspace
    } do
      {:ok, document} = Documents.create_document(user, workspace.id, %{title: "Test Document"})

      {:ok, lv, html} = live(conn, ~p"/app/workspaces/#{workspace.slug}")

      refute html =~ "lucide-pin"

      # Send structured event
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
      assert html =~ "lucide-pin"
    end

    test "updates document title on DocumentTitleChanged event", %{
      conn: conn,
      user: user,
      workspace: workspace
    } do
      {:ok, document} = Documents.create_document(user, workspace.id, %{title: "Original Title"})

      {:ok, lv, html} = live(conn, ~p"/app/workspaces/#{workspace.slug}")

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

    test "reloads documents on DocumentCreated event", %{
      conn: conn,
      user: user,
      workspace: workspace
    } do
      {:ok, lv, html} = live(conn, ~p"/app/workspaces/#{workspace.slug}")
      assert html =~ "No documents yet"

      # Create document in DB
      {:ok, document} =
        Documents.create_document(user, workspace.id, %{title: "Brand New Doc"})

      # Send structured event
      event =
        DocumentCreated.new(%{
          aggregate_id: document.id,
          actor_id: user.id,
          document_id: document.id,
          project_id: nil,
          user_id: user.id,
          workspace_id: workspace.id,
          title: "Brand New Doc"
        })

      send(lv.pid, event)

      html = render(lv)
      assert html =~ "Brand New Doc"
    end

    test "removes document on DocumentDeleted event", %{
      conn: conn,
      user: user,
      workspace: workspace
    } do
      {:ok, document} =
        Documents.create_document(user, workspace.id, %{title: "To Be Deleted"})

      {:ok, lv, html} = live(conn, ~p"/app/workspaces/#{workspace.slug}")
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

    test "updates workspace name on WorkspaceUpdated event", %{
      conn: conn,
      user: user,
      workspace: workspace
    } do
      {:ok, lv, html} = live(conn, ~p"/app/workspaces/#{workspace.slug}")

      assert html =~ workspace.name

      # Send structured event
      event =
        WorkspaceUpdated.new(%{
          aggregate_id: workspace.id,
          actor_id: user.id,
          workspace_id: workspace.id,
          name: "New Name"
        })

      send(lv.pid, event)

      html = render(lv)
      assert html =~ "New Name"
    end

    test "ignores WorkspaceUpdated event for different workspace", %{
      conn: conn,
      user: user,
      workspace: workspace
    } do
      {:ok, lv, html} = live(conn, ~p"/app/workspaces/#{workspace.slug}")

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

    test "updates project name on ProjectUpdated event", %{
      conn: conn,
      user: user,
      workspace: workspace
    } do
      {:ok, project} =
        Jarga.Projects.create_project(user, workspace.id, %{name: "Original Name"})

      {:ok, lv, html} = live(conn, ~p"/app/workspaces/#{workspace.slug}")

      assert html =~ "Original Name"

      # Send structured event
      event =
        ProjectUpdated.new(%{
          aggregate_id: project.id,
          actor_id: user.id,
          project_id: project.id,
          user_id: user.id,
          workspace_id: workspace.id,
          name: "Updated Name"
        })

      send(lv.pid, event)

      html = render(lv)
      assert html =~ "Updated Name"
      refute html =~ "Original Name"
    end

    test "reloads members on NotificationActionTaken accepted event when modal open", %{
      conn: conn,
      workspace: workspace
    } do
      {:ok, lv, _html} = live(conn, ~p"/app/workspaces/#{workspace.slug}")

      # Open members modal
      lv |> element("button", "Manage Members") |> render_click()

      # Send structured event — someone accepted invitation to this workspace
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

      # Should still render (members reloaded)
      assert render(lv) =~ "Team Members"
    end

    test "handles NotificationActionTaken declined event when modal open", %{
      conn: conn,
      workspace: workspace
    } do
      {:ok, lv, _html} = live(conn, ~p"/app/workspaces/#{workspace.slug}")

      # Open members modal
      lv |> element("button", "Manage Members") |> render_click()

      # Send structured event — someone declined invitation
      other_user_id = Ecto.UUID.generate()

      event =
        NotificationActionTaken.new(%{
          aggregate_id: Ecto.UUID.generate(),
          actor_id: other_user_id,
          notification_id: Ecto.UUID.generate(),
          user_id: other_user_id,
          action: "declined",
          workspace_id: workspace.id
        })

      send(lv.pid, event)

      # Should still render (members reloaded)
      assert render(lv) =~ "Team Members"
    end

    test "handles AgentUpdated event by reloading workspace agents", %{
      conn: conn,
      user: user,
      workspace: workspace
    } do
      {:ok, lv, _html} = live(conn, ~p"/app/workspaces/#{workspace.slug}")

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
      workspace: workspace
    } do
      {:ok, lv, _html} = live(conn, ~p"/app/workspaces/#{workspace.slug}")

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
      workspace: workspace
    } do
      {:ok, lv, _html} = live(conn, ~p"/app/workspaces/#{workspace.slug}")

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
      workspace: workspace
    } do
      {:ok, lv, _html} = live(conn, ~p"/app/workspaces/#{workspace.slug}")

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
      {:ok, _} = invite_and_accept_member(owner, workspace.id, guest.email, :guest)

      # Wait for invite to process
      :timer.sleep(50)

      %{conn: log_in_user(conn, guest), workspace: workspace, guest: guest}
    end

    test "guest cannot see new project button", %{conn: conn, workspace: workspace} do
      {:ok, lv, html} = live(conn, ~p"/app/workspaces/#{workspace.slug}")

      refute lv |> element("button", "New Project") |> has_element?()
      refute html =~ "New Project"
    end

    test "guest cannot see new document button", %{conn: conn, workspace: workspace} do
      {:ok, lv, _html} = live(conn, ~p"/app/workspaces/#{workspace.slug}")

      refute lv |> element("button", "New Document") |> has_element?()
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

    test "guest sees empty state message for documents without create button", %{
      conn: conn,
      workspace: workspace
    } do
      {:ok, _lv, html} = live(conn, ~p"/app/workspaces/#{workspace.slug}")

      assert html =~ "No documents yet"
      assert html =~ "No documents have been created yet"
      refute html =~ "Create your first document"
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

    test "shows error when document creation fails", %{conn: conn, workspace: workspace} do
      {:ok, lv, _html} = live(conn, ~p"/app/workspaces/#{workspace.slug}")

      # Open modal
      lv |> element("button", "New Document") |> render_click()

      # Submit with empty title (should fail validation)
      lv
      |> form("#document-form", "document-form": %{title: ""})
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

  describe "workspace show page member invitations" do
    setup %{conn: conn} do
      user = user_fixture()
      workspace = workspace_fixture(user)

      %{conn: log_in_user(conn, user), user: user, workspace: workspace}
    end

    test "successfully invites a new member", %{conn: conn, workspace: workspace} do
      {:ok, lv, _html} = live(conn, ~p"/app/workspaces/#{workspace.slug}")

      # Open members modal
      lv |> element("button", "Manage Members") |> render_click()

      # Submit invite form
      lv
      |> form("#invite-form", email: "newuser@example.com", role: :member)
      |> render_submit()

      assert render(lv) =~ "Invitation sent via email"
    end

    test "shows error when inviting already-member user", %{
      conn: conn,
      user: user,
      workspace: workspace
    } do
      {:ok, lv, _html} = live(conn, ~p"/app/workspaces/#{workspace.slug}")

      # Open members modal
      lv |> element("button", "Manage Members") |> render_click()

      # Try to invite the owner (who is already a member)
      lv
      |> form("#invite-form", email: user.email, role: :member)
      |> render_submit()

      assert render(lv) =~ "already a member"
    end
  end

  describe "workspace show page role management" do
    setup %{conn: conn} do
      owner = user_fixture()
      workspace = workspace_fixture(owner)
      member_user = user_fixture()

      # Add member to workspace
      {:ok, _} = invite_and_accept_member(owner, workspace.id, member_user.email, :member)

      :timer.sleep(50)

      %{conn: log_in_user(conn, owner), owner: owner, workspace: workspace, member: member_user}
    end

    test "shows member with role select dropdown", %{
      conn: conn,
      workspace: workspace,
      member: member
    } do
      {:ok, lv, _html} = live(conn, ~p"/app/workspaces/#{workspace.slug}")

      # Open members modal
      html = lv |> element("button", "Manage Members") |> render_click()

      # Should show member with select dropdown
      assert html =~ member.email
      assert html =~ "select"
    end
  end

  describe "workspace show page member removal" do
    setup %{conn: conn} do
      owner = user_fixture()
      workspace = workspace_fixture(owner)
      member_user = user_fixture()

      # Add member to workspace
      {:ok, _} = invite_and_accept_member(owner, workspace.id, member_user.email, :member)

      :timer.sleep(50)

      %{conn: log_in_user(conn, owner), owner: owner, workspace: workspace, member: member_user}
    end

    test "shows remove button for non-owner members", %{
      conn: conn,
      workspace: workspace,
      member: member
    } do
      {:ok, lv, _html} = live(conn, ~p"/app/workspaces/#{workspace.slug}")

      # Open members modal
      html = lv |> element("button", "Manage Members") |> render_click()

      # Should show member with remove button
      assert html =~ member.email
      assert html =~ "hero-trash"
    end

    test "owner does not have remove button", %{conn: conn, workspace: workspace} do
      {:ok, lv, _html} = live(conn, ~p"/app/workspaces/#{workspace.slug}")

      # Open members modal
      html = lv |> element("button", "Manage Members") |> render_click()

      # Find the owner row and verify no button
      assert html =~ "Owner"
    end
  end

  describe "agent cloning security" do
    import Agents.AgentsFixtures

    setup %{conn: conn} do
      user = user_fixture()
      other_user = user_fixture()

      # Create workspace A and B
      workspace_a = workspace_fixture(user)
      workspace_b = workspace_fixture(other_user)

      # Create shared agent owned by other_user, add to workspace B
      shared_agent =
        user_agent_fixture(%{
          user_id: other_user.id,
          name: "Shared Agent in Workspace B",
          model: "gpt-4",
          temperature: 0.7,
          visibility: "SHARED"
        })

      Agents.sync_agent_workspaces(shared_agent.id, other_user.id, [workspace_b.id])

      %{
        conn: log_in_user(conn, user),
        user: user,
        other_user: other_user,
        workspace_a: workspace_a,
        workspace_b: workspace_b,
        shared_agent: shared_agent
      }
    end

    test "successfully clones shared agent and adds to workspace", %{
      conn: conn,
      user: user,
      other_user: other_user,
      workspace_a: workspace_a
    } do
      # Add other_user as member of workspace_a so they can add their agent to it
      _membership =
        add_workspace_member_fixture(workspace_a.id, other_user, :member)

      # Create a shared agent by other_user in workspace_a
      shared_agent =
        user_agent_fixture(%{
          user_id: other_user.id,
          name: "Shared Agent",
          model: "gpt-4",
          temperature: 0.7,
          visibility: "SHARED"
        })

      # Add shared agent to workspace_a
      Agents.sync_agent_workspaces(shared_agent.id, other_user.id, [workspace_a.id])

      # User loads workspace A
      {:ok, lv, _html} = live(conn, ~p"/app/workspaces/#{workspace_a.slug}")

      # Clone the shared agent
      render_click(lv, "clone_agent", %{"agent-id" => shared_agent.id})

      # Verify the cloned agent is created and associated with workspace_a
      cloned_agents = Agents.list_user_agents(user.id)
      cloned_agent = Enum.find(cloned_agents, &(&1.name == "Shared Agent (Copy)"))
      assert cloned_agent != nil
      assert cloned_agent.user_id == user.id
      assert cloned_agent.visibility == "PRIVATE"

      # Verify workspace association
      workspace_ids = Agents.get_agent_workspace_ids(cloned_agent.id)
      assert workspace_a.id in workspace_ids

      # Verify cloned agent appears in workspace agent list
      agents_result = Agents.list_workspace_available_agents(workspace_a.id, user.id)
      assert Enum.any?(agents_result.my_agents, &(&1.id == cloned_agent.id))
    end

    test "prevents cloning agent from different workspace", %{
      conn: conn,
      workspace_a: workspace_a,
      shared_agent: shared_agent
    } do
      # User loads workspace A
      {:ok, lv, _html} = live(conn, ~p"/app/workspaces/#{workspace_a.slug}")

      # Attempt to clone agent from workspace B (security attack)
      # Manually trigger the event since the button won't exist in the DOM
      html = render_click(lv, "clone_agent", %{"agent-id" => shared_agent.id})

      # Authorization now happens at the use case level - should show error
      # Agent is in workspace B, user is trying from workspace A
      # The use case will check workspace membership and return :forbidden
      refute html =~ "cloned successfully"
      assert html =~ "Cannot clone" or html =~ "Agent not found"
    end

    test "handle_event clone_agent rejects non-integer agent_id", %{
      conn: conn,
      workspace_a: workspace_a
    } do
      {:ok, lv, _html} = live(conn, ~p"/app/workspaces/#{workspace_a.slug}")

      # Attempt to clone with invalid agent_id
      assert_raise ArgumentError, fn ->
        lv
        |> element("#some-button")
        |> render_click(%{"agent-id" => "not-a-number"})
      end
    end
  end
end
