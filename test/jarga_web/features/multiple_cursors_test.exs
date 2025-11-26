defmodule JargaWeb.Features.MultipleCursorsTest do
  use JargaWeb.FeatureCase, async: false

  @moduletag :javascript

  describe "multiple cursors" do
    setup do
      # Use persistent test users
      user_a = Jarga.TestUsers.get_user(:alice)
      user_b = Jarga.TestUsers.get_user(:bob)

      # Create a workspace and add user_b as a member
      workspace = workspace_fixture(user_a)
      {:ok, _invitation} = Workspaces.invite_member(user_a, workspace.id, user_b.email, :member)
      {:ok, _membership} = Workspaces.accept_invitation_by_workspace(workspace.id, user_b.id)

      # Create a public document in the workspace so both users can access it
      document = document_fixture(user_a, workspace, nil, %{is_public: true})

      {:ok, user_a: user_a, user_b: user_b, workspace: workspace, document: document}
    end

    @tag :javascript
    test "user cursors are visible to other users", %{
      session: session_a,
      user_a: user_a,
      user_b: user_b,
      workspace: workspace,
      document: document
    } do
      session_b = new_session()

      # Both users log in and open document
      session_a
      |> log_in_user(user_a)
      |> open_document(workspace.slug, document.slug)

      session_b
      |> log_in_user(user_b)
      |> open_document(workspace.slug, document.slug)

      # CRITICAL: Both users must click in editor to initialize awareness
      # This sets their selection state in Yjs awareness, which enables cursor rendering
      session_a
      |> click_in_editor()

      session_b
      |> click_in_editor()

      # User A types some text - this updates their cursor position
      session_a
      |> send_keys(["Hello from Alice"])

      # Wait for User B to see User A's cursor
      # The wait_for_cursor helper uses JavaScript to find cursors in ProseMirror decorations
      session_b
      |> wait_for_cursor("Alice", 3000)

      # If we got here, the cursor was found successfully
      # No additional assertions needed - wait_for_cursor validates the cursor exists

      close_session(session_b)
    end

    @tag :javascript
    test "cursor positions update in real-time as users type", %{
      session: session_a,
      user_a: user_a,
      user_b: user_b,
      workspace: workspace,
      document: document
    } do
      session_b = new_session()

      # Both users log in and open document
      session_a
      |> log_in_user(user_a)
      |> open_document(workspace.slug, document.slug)

      session_b
      |> log_in_user(user_b)
      |> open_document(workspace.slug, document.slug)

      # Both users click in editor to initialize awareness
      session_a
      |> click_in_editor()

      session_b
      |> click_in_editor()

      # User A starts typing
      session_a
      |> send_keys(["Line 1"])

      # User B should see User A's cursor
      session_b
      |> wait_for_cursor("Alice", 3000)

      # User A continues typing - cursor should move
      session_a
      |> send_keys(["\nLine 2"])

      # Cursor should still be visible (position updated)
      session_b
      |> wait_for_cursor("Alice", 2000)

      close_session(session_b)
    end

    @tag :javascript
    test "cursor disappears when user disconnects", %{
      session: session_a,
      user_a: user_a,
      user_b: user_b,
      workspace: workspace,
      document: document
    } do
      session_b = new_session()

      # Both users log in and open document
      session_a
      |> log_in_user(user_a)
      |> open_document(workspace.slug, document.slug)

      session_b
      |> log_in_user(user_b)
      |> open_document(workspace.slug, document.slug)

      # Both users click in editor to initialize awareness
      session_a
      |> click_in_editor()

      session_b
      |> click_in_editor()

      # User A types to establish cursor
      session_a
      |> send_keys(["I'm here"])

      # User B should see User A's cursor
      session_b
      |> wait_for_cursor("Alice", 3000)

      # User A disconnects (close session)
      close_session(session_a)

      # User B should no longer see User A's cursor (awareness cleanup happens automatically)
      session_b
      |> wait_for_cursor_to_disappear("Alice", 4000)
    end

    @tag :javascript
    test "multiple users see each other's cursors simultaneously", %{
      session: session_a,
      user_a: user_a,
      user_b: user_b,
      workspace: workspace,
      document: document
    } do
      session_b = new_session()

      # Both users log in and open document
      session_a
      |> log_in_user(user_a)
      |> open_document(workspace.slug, document.slug)

      session_b
      |> log_in_user(user_b)
      |> open_document(workspace.slug, document.slug)

      # Both users click in editor to initialize awareness
      session_a
      |> click_in_editor()

      session_b
      |> click_in_editor()

      # User A types
      session_a
      |> send_keys(["Alice is typing"])

      # User B types
      session_b
      |> send_keys(["Bob is also typing"])

      # User A should see User B's cursor
      session_a
      |> wait_for_cursor("Bob", 3000)

      # User B should see User A's cursor
      session_b
      |> wait_for_cursor("Alice", 3000)

      # Both cursors are visible - wait_for_cursor validates this
      # No additional assertions needed

      close_session(session_b)
    end
  end
end
