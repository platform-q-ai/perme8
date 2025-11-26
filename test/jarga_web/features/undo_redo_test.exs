defmodule JargaWeb.Features.UndoRedoTest do
  use JargaWeb.FeatureCase, async: false

  @moduletag :javascript

  describe "undo/redo (client-scoped)" do
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
    test "undo reverts only local user's changes", %{
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

      # Both users click to initialize Yjs sync
      session_a
      |> click_in_editor()

      session_b
      |> click_in_editor()

      # User A types "Hello"
      session_a
      |> send_keys(["Hello"])

      # User B types "World"
      session_b
      |> send_keys(["World"])

      # User A undoes their change
      session_a
      |> undo()

      # User A's content should be undone (no "Hello")
      # Wait for undo to process by checking content
      content_a = session_a |> get_editor_content()
      refute content_a =~ "Hello"
      assert content_a =~ "World"

      # User B's content should still have "World" (unaffected by A's undo)
      content_b = session_b |> get_editor_content()
      assert content_b =~ "World"

      close_session(session_b)
    end

    @tag :javascript
    test "redo re-applies local user's undone changes", %{
      session: session,
      user_a: user_a,
      workspace: workspace,
      document: document
    } do
      # User logs in and opens document
      session
      |> log_in_user(user_a)
      |> open_document(workspace.slug, document.slug)
      |> click_in_editor()

      # User types "Hello"
      session
      |> send_keys(["Hello"])

      # Verify "Hello" is there
      content = session |> get_editor_content()
      assert content =~ "Hello"

      # User undoes
      session
      |> undo()

      # "Hello" should be gone
      content = session |> get_editor_content()
      refute content =~ "Hello"

      # User redoes
      session
      |> redo()

      # "Hello" should reappear
      content = session |> get_editor_content()
      assert content =~ "Hello"
    end

    @tag :javascript
    test "undo does not affect other users' undo stacks", %{
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

      # Both users click to initialize
      session_a
      |> click_in_editor()

      session_b
      |> click_in_editor()

      # User A types "A"
      session_a
      |> send_keys(["A"])

      # User B types "B"
      session_b
      |> send_keys(["B"])

      # Both should have both letters
      content_a = session_a |> get_editor_content()
      content_b = session_b |> get_editor_content()
      assert content_a =~ "A"
      assert content_a =~ "B"
      assert content_b =~ "A"
      assert content_b =~ "B"

      # User A undoes their change
      session_a
      |> undo()

      # User A should no longer have "A"
      content_a = session_a |> get_editor_content()
      refute content_a =~ "A"
      assert content_a =~ "B"

      # User B should still have both (B's undo stack is independent)
      content_b = session_b |> get_editor_content()
      assert content_b =~ "B"

      # User B can undo their own change independently
      session_b
      |> undo()

      # User B should no longer have "B"
      content_b = session_b |> get_editor_content()
      refute content_b =~ "B"

      close_session(session_b)
    end

    @tag :javascript
    test "undo works correctly after remote changes", %{
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

      # Both users click to initialize
      session_a
      |> click_in_editor()

      session_b
      |> click_in_editor()

      # User A types "Hello"
      session_a
      |> send_keys(["Hello"])

      # Wait for "Hello" to sync
      session_a |> wait_for_text_in_editor("Hello")
      session_b |> wait_for_text_in_editor("Hello")

      # User B types "World"
      session_b
      |> send_keys(["World"])

      # Wait for "World" to sync
      session_a |> wait_for_text_in_editor("World")
      session_b |> wait_for_text_in_editor("World")

      # User A types more text "!"
      session_a
      |> send_keys(["!"])

      # Wait for "!" to sync
      session_a |> wait_for_text_in_editor("!")
      session_b |> wait_for_text_in_editor("!")

      # Both users should have all content
      content_a = session_a |> get_editor_content()
      content_b = session_b |> get_editor_content()
      assert content_a =~ "Hello"
      assert content_a =~ "World"
      assert content_a =~ "!"
      assert content_b =~ "Hello"
      assert content_b =~ "World"
      assert content_b =~ "!"

      # User A undoes their last change
      # In Yjs collaborative editing, "Hello" and "!" are batched as one undo operation
      # because they were typed in quick succession by the same user
      # Importantly, undo affects the shared document state, not just local view
      session_a
      |> undo()

      # User A's entire contribution ("Hello!") should be removed from the shared document
      # Only User B's "World" should remain
      content_a = session_a |> get_editor_content()
      refute content_a =~ "Hello"
      refute content_a =~ "!"
      assert content_a =~ "World"

      # User B sees the same state - User A's undo removed "Hello!" from shared doc
      # This is correct Yjs behavior: undo modifies the shared document state
      content_b = session_b |> get_editor_content()
      refute content_b =~ "Hello"
      refute content_b =~ "!"
      assert content_b =~ "World"

      close_session(session_b)
    end
  end
end
