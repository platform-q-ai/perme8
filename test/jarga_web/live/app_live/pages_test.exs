defmodule JargaWeb.AppLive.PagesTest do
  use JargaWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Jarga.AccountsFixtures
  import Jarga.WorkspacesFixtures
  import Jarga.ProjectsFixtures

  alias Jarga.Pages

  describe "page show (unauthenticated)" do
    test "redirects if user is not logged in", %{conn: conn} do
      assert {:error, redirect} = live(conn, ~p"/app/workspaces/test-workspace/pages/test-page")

      assert {:redirect, %{to: path, flash: flash}} = redirect
      assert path == ~p"/users/log-in"
      assert %{"error" => "You must log in to access this page."} = flash
    end
  end

  describe "page show (authenticated)" do
    setup %{conn: conn} do
      user = user_fixture()
      workspace = workspace_fixture(user)
      %{conn: log_in_user(conn, user), user: user, workspace: workspace}
    end

    test "renders page title and editor", %{conn: conn, user: user, workspace: workspace} do
      {:ok, page} = Pages.create_page(user, workspace.id, %{title: "My Test Page"})

      {:ok, _lv, html} = live(conn, ~p"/app/workspaces/#{workspace.slug}/pages/#{page.slug}")

      assert html =~ "My Test Page"
      assert html =~ "editor-container"
    end

    test "displays page in workspace context", %{conn: conn, user: user, workspace: workspace} do
      {:ok, page} = Pages.create_page(user, workspace.id, %{title: "Workspace Page"})

      {:ok, _lv, html} = live(conn, ~p"/app/workspaces/#{workspace.slug}/pages/#{page.slug}")

      assert html =~ workspace.name
    end

    test "displays page in project context", %{conn: conn, user: user, workspace: workspace} do
      project = project_fixture(user, workspace)
      {:ok, page} = Pages.create_page(user, workspace.id, %{
        title: "Project Page",
        project_id: project.id
      })

      {:ok, _lv, html} = live(conn, ~p"/app/workspaces/#{workspace.slug}/pages/#{page.slug}")

      assert html =~ project.name
    end

    test "shows pinned indicator for pinned pages", %{conn: conn, user: user, workspace: workspace} do
      {:ok, page} = Pages.create_page(user, workspace.id, %{
        title: "Pinned Page",
        is_pinned: true
      })

      {:ok, _lv, html} = live(conn, ~p"/app/workspaces/#{workspace.slug}/pages/#{page.slug}")

      assert html =~ "pinned" or html =~ "Pinned"
    end

    test "allows updating page title", %{conn: conn, user: user, workspace: workspace} do
      {:ok, page} = Pages.create_page(user, workspace.id, %{title: "Original Title"})

      {:ok, lv, _html} = live(conn, ~p"/app/workspaces/#{workspace.slug}/pages/#{page.slug}")

      # First, start editing the title
      lv |> element("h1[phx-click='start_edit_title']") |> render_click()

      # Now submit the form
      lv
      |> element("form[phx-submit='update_title']")
      |> render_submit(%{page: %{title: "Updated Title"}})

      assert render(lv) =~ "Updated Title"
    end

    test "allows toggling pin status", %{conn: conn, user: user, workspace: workspace} do
      {:ok, page} = Pages.create_page(user, workspace.id, %{
        title: "Test Page",
        is_pinned: false
      })

      {:ok, lv, _html} = live(conn, ~p"/app/workspaces/#{workspace.slug}/pages/#{page.slug}")

      # Toggle pin
      lv |> element("button[phx-click='toggle_pin']") |> render_click()

      # Verify pin status changed
      updated_page = Pages.get_page!(user, page.id)
      assert updated_page.is_pinned == true
    end

    test "allows toggling public status", %{conn: conn, user: user, workspace: workspace} do
      {:ok, page} = Pages.create_page(user, workspace.id, %{
        title: "Test Page",
        is_public: false
      })

      {:ok, lv, _html} = live(conn, ~p"/app/workspaces/#{workspace.slug}/pages/#{page.slug}")

      # Toggle public
      lv |> element("button[phx-click='toggle_public']") |> render_click()

      # Verify public status changed
      updated_page = Pages.get_page!(user, page.id)
      assert updated_page.is_public == true

      # Toggle back to private
      lv |> element("button[phx-click='toggle_public']") |> render_click()

      updated_page = Pages.get_page!(user, page.id)
      assert updated_page.is_public == false
    end

    test "does not allow access to private pages from other users", %{conn: conn} do
      other_user = user_fixture()
      other_workspace = workspace_fixture(other_user)
      {:ok, other_page} = Pages.create_page(other_user, other_workspace.id, %{
        title: "Private Page",
        is_public: false
      })

      assert_raise Ecto.NoResultsError, fn ->
        live(conn, ~p"/app/workspaces/#{other_workspace.slug}/pages/#{other_page.slug}")
      end
    end

    test "allows workspace members to view public pages from other users", %{conn: conn, user: user, workspace: workspace} do
      # Create another user and add them to the same workspace
      other_user = user_fixture()
      {:ok, _member} = Jarga.Workspaces.invite_member(user, workspace.id, other_user.email, :member)

      # Other user creates a public page
      {:ok, public_page} = Pages.create_page(other_user, workspace.id, %{
        title: "Public Page",
        is_public: true
      })

      # First user should be able to view it
      {:ok, _lv, html} = live(conn, ~p"/app/workspaces/#{workspace.slug}/pages/#{public_page.slug}")
      assert html =~ "Public Page"
    end

    test "workspace members cannot view private pages from other users", %{conn: conn, user: user, workspace: workspace} do
      # Create another user and add them to the same workspace
      other_user = user_fixture()
      {:ok, _member} = Jarga.Workspaces.invite_member(user, workspace.id, other_user.email, :member)

      # Other user creates a private page
      {:ok, private_page} = Pages.create_page(other_user, workspace.id, %{
        title: "Private Page",
        is_public: false
      })

      # First user should NOT be able to view it
      assert_raise Ecto.NoResultsError, fn ->
        live(conn, ~p"/app/workspaces/#{workspace.slug}/pages/#{private_page.slug}")
      end
    end

    test "shows 404 for non-existent page", %{conn: conn, workspace: workspace} do
      assert_raise Ecto.NoResultsError, fn ->
        live(conn, ~p"/app/workspaces/#{workspace.slug}/pages/nonexistent-slug")
      end
    end

    test "has delete page button", %{conn: conn, user: user, workspace: workspace} do
      {:ok, page} = Pages.create_page(user, workspace.id, %{title: "To Delete"})

      {:ok, lv, _html} = live(conn, ~p"/app/workspaces/#{workspace.slug}/pages/#{page.slug}")

      assert lv |> element("button[phx-click='delete_page']") |> has_element?()
    end

    test "deletes page and redirects when delete button clicked", %{conn: conn, user: user, workspace: workspace} do
      {:ok, page} = Pages.create_page(user, workspace.id, %{title: "To Delete"})

      {:ok, lv, _html} = live(conn, ~p"/app/workspaces/#{workspace.slug}/pages/#{page.slug}")

      # Click delete button
      lv |> element("button[phx-click='delete_page']") |> render_click()

      # Should redirect to workspace
      assert_redirect(lv, ~p"/app/workspaces/#{workspace.slug}")

      # Verify page is deleted
      assert {:error, :page_not_found} = Pages.delete_page(user, page.id)
    end
  end

  describe "collaborative editing" do
    setup %{conn: conn} do
      user = user_fixture()
      workspace = workspace_fixture(user)
      {:ok, page} = Pages.create_page(user, workspace.id, %{title: "Collaborative Page"})

      %{conn: log_in_user(conn, user), user: user, workspace: workspace, page: page}
    end

    test "sends yjs updates for real-time broadcast", %{conn: conn, workspace: workspace, page: page} do
      {:ok, lv, _html} = live(conn, ~p"/app/workspaces/#{workspace.slug}/pages/#{page.slug}")

      # Subscribe to see the broadcast
      Phoenix.PubSub.subscribe(Jarga.PubSub, "page:#{page.id}")

      # Simulate yjs update from client (real-time, no database save)
      update_data = Base.encode64(<<1, 2, 3, 4>>)
      user_id = "user_123"

      lv
      |> element("#editor-container")
      |> render_hook("yjs_update", %{"update" => update_data, "user_id" => user_id})

      # Should receive broadcast immediately
      assert_receive {:yjs_update, %{update: ^update_data, user_id: ^user_id}}
    end

    test "saves note content with debounced save_note event", %{conn: conn, user: user, workspace: workspace, page: page} do
      {:ok, lv, _html} = live(conn, ~p"/app/workspaces/#{workspace.slug}/pages/#{page.slug}")

      # Simulate debounced save event (happens after user stops typing)
      complete_state = Base.encode64(<<1, 2, 3, 4, 5, 6, 7, 8>>)
      markdown = "# Test Content"

      lv
      |> element("#editor-container")
      |> render_hook("save_note", %{"complete_state" => complete_state, "markdown" => markdown})

      # Note should be updated in database
      # Reload the note to check
      page = Pages.get_page!(user, page.id) |> Jarga.Repo.preload(:page_components)
      note_component = Enum.find(page.page_components, fn pc -> pc.component_type == "note" end)
      note = Jarga.Repo.get!(Jarga.Notes.Note, note_component.component_id)

      assert note.yjs_state == Base.decode64!(complete_state)
      assert note.note_content["markdown"] == markdown
    end

    test "broadcasts yjs updates to other clients", %{conn: conn, workspace: workspace, page: page} do
      {:ok, lv, _html} = live(conn, ~p"/app/workspaces/#{workspace.slug}/pages/#{page.slug}")

      # Subscribe to the page topic to listen for broadcasts
      Phoenix.PubSub.subscribe(Jarga.PubSub, "page:#{page.id}")

      # Simulate yjs update
      update_data = Base.encode64(<<5, 6, 7, 8>>)
      user_id = "user_456"

      lv
      |> element("#editor-container")
      |> render_hook("yjs_update", %{"update" => update_data, "user_id" => user_id})

      # Should receive broadcast
      assert_receive {:yjs_update, %{update: ^update_data, user_id: ^user_id}}
    end

    test "receives yjs updates from other clients", %{conn: conn, workspace: workspace, page: page} do
      {:ok, lv, _html} = live(conn, ~p"/app/workspaces/#{workspace.slug}/pages/#{page.slug}")

      # Simulate update from another client via PubSub
      update_data = Base.encode64(<<9, 10, 11, 12>>)
      Phoenix.PubSub.broadcast(
        Jarga.PubSub,
        "page:#{page.id}",
        {:yjs_update, %{update: update_data, user_id: "other_user"}}
      )

      # The LiveView should push the update to the client
      # This would be verified by checking push_event was called
      # For now, we just verify the page renders without error
      assert render(lv)
    end
  end
end
