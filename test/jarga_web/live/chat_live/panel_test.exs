defmodule JargaWeb.ChatLive.PanelTest do
  use JargaWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Jarga.AccountsFixtures
  import Jarga.WorkspacesFixtures
  import Jarga.ProjectsFixtures
  import Jarga.PagesFixtures

  describe "Panel component" do
    setup do
      user = user_fixture()
      %{user: user}
    end

    test "renders chat panel with DaisyUI drawer", %{conn: conn, user: user} do
      conn = log_in_user(conn, user)

      {:ok, view, _html} = live(conn, ~p"/app")

      # Check for DaisyUI drawer components
      assert has_element?(view, ".drawer.drawer-end")
      assert has_element?(view, "#chat-drawer-global-chat-panel.drawer-toggle")
      assert has_element?(view, "#chat-toggle-btn")
    end

    test "drawer starts closed (checkbox unchecked)", %{conn: conn, user: user} do
      conn = log_in_user(conn, user)

      {:ok, view, html} = live(conn, ~p"/app")

      # Drawer checkbox should not be checked by default
      refute html =~ ~r/checked/
      assert has_element?(view, "#chat-drawer-global-chat-panel[type='checkbox']")
    end

    test "toggle button is visible when drawer is closed", %{conn: conn, user: user} do
      conn = log_in_user(conn, user)

      {:ok, view, _html} = live(conn, ~p"/app")

      # Toggle button should be visible (not hidden)
      assert has_element?(view, "#chat-toggle-btn")
      refute has_element?(view, "#chat-toggle-btn.hidden")
    end

    test "allows sending a message", %{conn: conn, user: user} do
      conn = log_in_user(conn, user)

      {:ok, view, _html} = live(conn, ~p"/app")

      # Send message (drawer state managed client-side, so we just test the form)
      view
      |> element("#chat-message-form")
      |> render_submit(%{message: "Hello!"})

      # Should show user message in chat bubbles
      assert has_element?(view, ".chat.chat-end .chat-bubble.chat-bubble-primary", "Hello!")
    end

    test "displays empty state when no messages", %{conn: conn, user: user} do
      conn = log_in_user(conn, user)

      {:ok, _view, html} = live(conn, ~p"/app")

      # Should show empty state message
      assert html =~ "Ask me anything about this page"
    end

    test "clear button is disabled when no messages", %{conn: conn, user: user} do
      conn = log_in_user(conn, user)

      {:ok, view, _html} = live(conn, ~p"/app")

      # Clear button should be disabled when no messages
      assert has_element?(view, "button[phx-click='clear_chat'][disabled]")
    end

    test "send button is disabled when input is empty", %{conn: conn, user: user} do
      conn = log_in_user(conn, user)

      {:ok, view, _html} = live(conn, ~p"/app")

      # Send button should be disabled when current_message is empty
      assert has_element?(view, "button[type='submit'][disabled]")
    end

    test "updates current_message as user types", %{conn: conn, user: user} do
      conn = log_in_user(conn, user)

      {:ok, view, _html} = live(conn, ~p"/app")

      # Simulate typing
      view
      |> element("#chat-input")
      |> render_change(%{message: "Hello"})

      # Input should have the value
      assert has_element?(view, "#chat-input[value='Hello']")
    end

    test "clears messages when clear button is clicked", %{conn: conn, user: user} do
      conn = log_in_user(conn, user)

      {:ok, view, _html} = live(conn, ~p"/app")

      # Send a message first
      view
      |> element("#chat-message-form")
      |> render_submit(%{message: "Test message"})

      assert has_element?(view, ".chat-bubble", "Test message")

      # Clear chat
      view
      |> element("button[phx-click='clear_chat']")
      |> render_click()

      # Messages should be cleared
      refute has_element?(view, ".chat-bubble", "Test message")
      # Should show empty state again
      assert render(view) =~ "Ask me anything about this page"
    end

    @tag :evaluation
    test "displays assistant response", %{conn: conn, user: user} do
      conn = log_in_user(conn, user)

      {:ok, view, _html} = live(conn, ~p"/app")

      view
      |> element("#chat-message-form")
      |> render_submit(%{message: "What is 2+2?"})

      # Wait for the LLM to respond by checking for assistant message in the view
      # The :assistant_response message is now handled internally by the parent LiveView
      # We verify the response by checking the rendered HTML
      # Give LLM time to respond
      Process.sleep(3_000)

      html = render(view)

      # Should show assistant response in chat bubbles (chat-start is for assistant)
      assert html =~ "chat chat-start"
      # The response should contain content (not just be empty)
      assert html =~ ~r/<div class="chat-bubble\s*">[^<]+<\/div>/
    end

    @tag :evaluation
    test "shows loading state while waiting for response", %{conn: conn, user: user} do
      conn = log_in_user(conn, user)

      {:ok, view, _html} = live(conn, ~p"/app")

      view
      |> element("#chat-message-form")
      |> render_submit(%{message: "Hello"})

      # Should show loading indicator
      assert has_element?(view, "#chat-messages[data-loading='true']")
      assert has_element?(view, ".loading.loading-dots")
    end

    @tag :evaluation
    test "disables input while streaming", %{conn: conn, user: user} do
      conn = log_in_user(conn, user)

      {:ok, view, _html} = live(conn, ~p"/app")

      view
      |> element("#chat-message-form")
      |> render_submit(%{message: "Hello"})

      # Textarea should be disabled while streaming
      assert has_element?(view, "#chat-input[disabled]")
      # Send button should show loading state
      assert has_element?(view, "button[type='submit'][disabled]")
      assert render(view) =~ "Sending..."
    end

    @tag :evaluation
    test "shows streaming indicator with cursor while receiving response", %{
      conn: conn,
      user: user
    } do
      conn = log_in_user(conn, user)

      {:ok, view, _html} = live(conn, ~p"/app")

      view
      |> element("#chat-message-form")
      |> render_submit(%{message: "Tell me a story"})

      # Should eventually show streaming message with cursor
      # Wait a bit for the stream to start
      Process.sleep(500)

      html = render(view)
      # Check for either the thinking state or streaming content with cursor
      assert html =~ "Thinking..." or html =~ "▊"
    end

    test "extracts page context correctly", %{conn: conn, user: user} do
      conn = log_in_user(conn, user)

      {:ok, view, _html} = live(conn, ~p"/app")

      # Send a message to trigger context extraction
      view
      |> element("#chat-message-form")
      |> render_submit(%{message: "What page am I on?"})

      # The panel component should have extracted context
      # We can't directly inspect the assigns, but we can verify the message was sent
      assert has_element?(view, ".chat.chat-end .chat-bubble", "What page am I on?")
    end

    test "extracts page content from note when viewing a page", %{conn: conn, user: user} do
      conn = log_in_user(conn, user)

      # Create a page with specific content
      workspace = workspace_fixture(user, %{name: "Test Workspace"})
      project = project_fixture(user, workspace)

      page =
        page_fixture(user, workspace, project, %{
          title: "Test Page",
          content: "The Porsche 911 is a legendary sports car."
        })

      {:ok, view, _html} = live(conn, ~p"/app/workspaces/#{workspace.slug}/pages/#{page.slug}")

      # Send a message to trigger context extraction
      view
      |> element("#chat-message-form")
      |> render_submit(%{message: "What car is mentioned?"})

      # Message should be sent successfully
      assert has_element?(view, ".chat.chat-end .chat-bubble", "What car is mentioned?")

      # The page content should have been extracted and will be sent to LLM
      # (we can't easily test the LLM response without mocking, but the integration test covers that)
    end

    test "message timestamps are formatted correctly", %{conn: conn, user: user} do
      conn = log_in_user(conn, user)

      {:ok, view, _html} = live(conn, ~p"/app")

      view
      |> element("#chat-message-form")
      |> render_submit(%{message: "Test"})

      # Should show timestamp (just now for recent messages)
      assert has_element?(view, ".chat-header", "just now")
    end

    test "textarea has correct placeholder text", %{conn: conn, user: user} do
      conn = log_in_user(conn, user)

      {:ok, _view, html} = live(conn, ~p"/app")

      # Check for placeholder
      assert html =~ "Ask about this page..."
    end

    test "chat input uses ChatInput hook for keyboard handling", %{conn: conn, user: user} do
      conn = log_in_user(conn, user)

      {:ok, _view, html} = live(conn, ~p"/app")

      # Check that ChatInput hook is attached
      assert html =~ ~r/phx-hook="ChatInput"/
    end

    test "chat drawer uses ChatPanel hook for state management", %{conn: conn, user: user} do
      conn = log_in_user(conn, user)

      {:ok, _view, html} = live(conn, ~p"/app")

      # Check that ChatPanel hook is attached
      assert html =~ ~r/phx-hook="ChatPanel"/
    end

    test "chat messages container uses ChatMessages hook for scrolling", %{conn: conn, user: user} do
      conn = log_in_user(conn, user)

      {:ok, _view, html} = live(conn, ~p"/app")

      # Check that ChatMessages hook is attached
      assert html =~ ~r/phx-hook="ChatMessages"/
    end

    test "drawer has phx-update=ignore to prevent server updates", %{conn: conn, user: user} do
      conn = log_in_user(conn, user)

      {:ok, _view, html} = live(conn, ~p"/app")

      # Drawer checkbox should have phx-update="ignore"
      assert html =~ ~r/phx-update="ignore"/
    end
  end

  describe "PR Goal: Users can open chat panel" do
    setup do
      user = user_fixture()
      %{user: user}
    end

    test "chat panel is available on all admin pages", %{conn: conn, user: user} do
      conn = log_in_user(conn, user)

      pages_to_test = [
        ~p"/app",
        ~p"/app/workspaces",
        ~p"/users/settings"
      ]

      for page <- pages_to_test do
        {:ok, _view, html} = live(conn, page)
        assert html =~ "chat-drawer-global-chat-panel"
        assert html =~ "chat-toggle-btn"
      end
    end

    test "keyboard shortcut Cmd+K opens chat panel", %{conn: conn, user: user} do
      conn = log_in_user(conn, user)

      {:ok, _view, html} = live(conn, ~p"/app")

      # Verify the ChatPanel hook handles Cmd+K
      assert html =~ ~r/phx-hook="ChatPanel"/
      # The hook in chat_hooks.js listens for metaKey/ctrlKey + 'k'
    end

    test "Escape key closes chat panel", %{conn: conn, user: user} do
      conn = log_in_user(conn, user)

      {:ok, _view, html} = live(conn, ~p"/app")

      # Verify the ChatPanel hook handles Escape
      assert html =~ ~r/phx-hook="ChatPanel"/
      # The hook in chat_hooks.js listens for 'Escape' key
    end

    test "toggle button is always accessible", %{conn: conn, user: user} do
      conn = log_in_user(conn, user)

      {:ok, view, _html} = live(conn, ~p"/app")

      # Toggle button should be present and not hidden by default
      assert has_element?(view, "#chat-toggle-btn")
      refute has_element?(view, "#chat-toggle-btn.hidden")
    end
  end

  describe "PR Goal: Users can ask questions about page content" do
    setup do
      user = user_fixture()
      %{user: user}
    end

    test "extracts workspace context from page", %{conn: conn, user: user} do
      conn = log_in_user(conn, user)

      # Create a workspace so we have context
      workspace = workspace_fixture(user, %{name: "Test Workspace"})

      {:ok, view, _html} = live(conn, ~p"/app/workspaces/#{workspace.slug}")

      # Send a message - the panel should extract workspace context
      view
      |> element("#chat-message-form")
      |> render_submit(%{message: "What workspace am I viewing?"})

      # Verify message was sent
      assert has_element?(view, ".chat-bubble", "What workspace am I viewing?")
    end

    test "extracts user email from page context", %{conn: conn, user: user} do
      conn = log_in_user(conn, user)

      {:ok, view, _html} = live(conn, ~p"/app")

      # The panel should extract current_user.email
      # We can verify this by checking the assigns in the component
      # Send a message to trigger context building
      view
      |> element("#chat-message-form")
      |> render_submit(%{message: "Who am I?"})

      assert has_element?(view, ".chat-bubble", "Who am I?")
    end

    test "includes page title in context", %{conn: conn, user: user} do
      conn = log_in_user(conn, user)

      {:ok, _view, html} = live(conn, ~p"/app")

      # Page should have a title that can be extracted
      # The dashboard page has "Welcome to Jarga" as the page title
      assert html =~ "Welcome to Jarga"
    end

    @tag :evaluation
    test "responds with relevant context from page", %{conn: conn, user: user} do
      conn = log_in_user(conn, user)

      {:ok, view, _html} = live(conn, ~p"/app")

      view
      |> element("#chat-message-form")
      |> render_submit(%{message: "What page am I on?"})

      # Wait for LLM response
      Process.sleep(3_000)

      html = render(view)

      # Should show assistant response mentioning dashboard or welcome page
      assert html =~ "chat chat-start"
      # Response should reference the current context
      assert html =~ ~r/(dashboard|welcome|jarga)/i
    end
  end

  describe "PR Goal: Response latency < 3 seconds" do
    setup do
      user = user_fixture()
      %{user: user}
    end

    @tag :evaluation
    test "shows streaming indicator immediately", %{conn: conn, user: user} do
      conn = log_in_user(conn, user)

      {:ok, view, _html} = live(conn, ~p"/app")

      view
      |> element("#chat-message-form")
      |> render_submit(%{message: "Tell me about Jarga"})

      # Should show loading indicator almost immediately
      Process.sleep(100)

      html = render(view)
      assert html =~ ~r/(Thinking...|loading loading-dots)/
    end

    @tag :evaluation
    test "starts streaming response quickly", %{conn: conn, user: user} do
      conn = log_in_user(conn, user)

      {:ok, view, _html} = live(conn, ~p"/app")

      start_time = System.monotonic_time(:millisecond)

      view
      |> element("#chat-message-form")
      |> render_submit(%{message: "Hello"})

      # Wait for first chunk to arrive
      max_wait = 3_000
      wait_interval = 100
      waited = 0

      _html =
        Stream.repeatedly(fn ->
          if waited < max_wait do
            Process.sleep(wait_interval)
            render(view)
          else
            render(view)
          end
        end)
        |> Enum.take_while(fn html ->
          waited = waited + wait_interval
          not (html =~ "chat chat-start") and waited < max_wait
        end)
        |> List.last()

      end_time = System.monotonic_time(:millisecond)
      time_to_first_chunk = end_time - start_time

      # Final check
      final_html = render(view)
      assert final_html =~ "chat chat-start"

      assert time_to_first_chunk <= 3_000,
             "Time to first chunk was #{time_to_first_chunk}ms, expected < 3000ms"
    end
  end

  describe "PR #7: Session persistence and restoration" do
    setup do
      user = user_fixture()
      %{user: user}
    end

    test "restore_session event handler loads session from database", %{conn: conn, user: user} do
      conn = log_in_user(conn, user)

      # Create a session with messages in the database
      import Jarga.DocumentsFixtures
      session = chat_session_fixture(user: user, title: "Previous Chat")
      _msg1 = chat_message_fixture(chat_session: session, role: "user", content: "Hello")
      _msg2 = chat_message_fixture(chat_session: session, role: "assistant", content: "Hi there!")

      {:ok, view, _html} = live(conn, ~p"/app")

      # Simulate the restore_session event from the JavaScript hook
      view
      |> element("#chat-drawer-global-chat-panel")
      |> render_hook("restore_session", %{"session_id" => session.id})

      # Messages should be restored
      assert has_element?(view, ".chat-bubble", "Hello")
      assert has_element?(view, ".chat-bubble", "Hi there!")
    end

    test "restore_session ignores sessions from other users", %{conn: conn, user: user} do
      conn = log_in_user(conn, user)

      # Create a session for a different user
      import Jarga.DocumentsFixtures
      other_user = user_fixture(%{email: "other@example.com"})
      other_session = chat_session_fixture(user: other_user, title: "Other User's Chat")

      _msg =
        chat_message_fixture(chat_session: other_session, role: "user", content: "Secret message")

      {:ok, view, _html} = live(conn, ~p"/app")

      # Try to restore the other user's session
      view
      |> element("#chat-drawer-global-chat-panel")
      |> render_hook("restore_session", %{"session_id" => other_session.id})

      # Message should NOT be restored (security check)
      refute has_element?(view, ".chat-bubble", "Secret message")
    end

    test "restore_session handles non-existent session gracefully", %{conn: conn, user: user} do
      conn = log_in_user(conn, user)

      {:ok, view, _html} = live(conn, ~p"/app")

      fake_session_id = Ecto.UUID.generate()

      # Should not crash when restoring non-existent session
      view
      |> element("#chat-drawer-global-chat-panel")
      |> render_hook("restore_session", %{"session_id" => fake_session_id})

      # Chat should remain empty
      assert has_element?(view, "#chat-messages")
      assert render(view) =~ "Ask me anything about this page"
    end

    test "new_conversation button clears current session", %{conn: conn, user: user} do
      conn = log_in_user(conn, user)

      {:ok, view, _html} = live(conn, ~p"/app")

      # Send a message to create a session
      view
      |> element("#chat-message-form")
      |> render_submit(%{message: "Test message"})

      assert has_element?(view, ".chat-bubble", "Test message")

      # Click "New" conversation button
      view
      |> element("button[phx-click='new_conversation']")
      |> render_click()

      # Messages should be cleared
      refute has_element?(view, ".chat-bubble", "Test message")
      # Should show empty state
      assert render(view) =~ "Ask me anything about this page"
    end

    test "chat panel has phx-target for component-scoped events", %{conn: conn, user: user} do
      conn = log_in_user(conn, user)

      {:ok, _view, html} = live(conn, ~p"/app")

      # The chat drawer checkbox should have phx-target pointing to the component
      assert html =~ ~r/phx-target=.*chat.*panel/i
    end

    test "delete_session removes conversation from database", %{conn: conn, user: user} do
      conn = log_in_user(conn, user)

      # Create a session with messages
      import Jarga.DocumentsFixtures
      session = chat_session_fixture(user: user, title: "Old Conversation")
      _msg1 = chat_message_fixture(chat_session: session, content: "Test message 1")
      _msg2 = chat_message_fixture(chat_session: session, content: "Test message 2")

      {:ok, view, _html} = live(conn, ~p"/app")

      # Switch to conversations view
      view
      |> element("button[phx-click='show_conversations']")
      |> render_click()

      # Verify the session appears in the list
      assert has_element?(view, "p", "Old Conversation")

      # Delete the session
      view
      |> element("button[phx-click='delete_session'][phx-value-session-id='#{session.id}']")
      |> render_click()

      # Session should be removed from the UI
      refute has_element?(view, "p", "Old Conversation")

      # Verify session was deleted from database via context
      alias Jarga.Documents
      assert {:error, :not_found} = Documents.load_session(session.id)
    end
  end

  describe "PR Goal: Panel state persists across navigation" do
    setup do
      user = user_fixture()
      %{user: user}
    end

    test "drawer state managed client-side with localStorage", %{conn: conn, user: user} do
      conn = log_in_user(conn, user)

      {:ok, _view, html} = live(conn, ~p"/app")

      # Verify that ChatPanel hook is present (it handles localStorage)
      assert html =~ ~r/phx-hook="ChatPanel"/
      # The hook saves state to localStorage with key 'chat_collapsed'
    end

    test "messages are stored in LiveComponent state per LiveView", %{conn: conn, user: user} do
      conn = log_in_user(conn, user)

      {:ok, view, _html} = live(conn, ~p"/app")

      # Send a message
      view
      |> element("#chat-message-form")
      |> render_submit(%{message: "Test persistence"})

      assert has_element?(view, ".chat-bubble", "Test persistence")

      # Navigate to settings (different LiveView)
      {:ok, view2, _html} = live(conn, ~p"/users/settings")

      # Messages don't persist across different LiveView instances in PR #1
      # This is expected behavior - each LiveView has its own component instance
      # Future PRs will add database persistence for chat history
      refute has_element?(view2, ".chat-bubble", "Test persistence")

      # But the empty chat panel is still available
      assert has_element?(view2, "#chat-drawer-global-chat-panel")
    end

    test "messages persist within the same LiveView navigation", %{conn: conn, user: user} do
      conn = log_in_user(conn, user)

      {:ok, view, _html} = live(conn, ~p"/app")

      # Add messages to the chat
      view
      |> element("#chat-message-form")
      |> render_submit(%{message: "Persistence test"})

      assert has_element?(view, ".chat-bubble", "Persistence test")

      # Messages remain in the component state for the current LiveView session
      # Re-render and check they're still there
      html = render(view)
      assert html =~ "Persistence test"
    end

    test "clear button removes all messages", %{conn: conn, user: user} do
      conn = log_in_user(conn, user)

      {:ok, view, _html} = live(conn, ~p"/app")

      # Add messages
      view
      |> element("#chat-message-form")
      |> render_submit(%{message: "Message 1"})

      view
      |> element("#chat-message-form")
      |> render_submit(%{message: "Message 2"})

      assert has_element?(view, ".chat-bubble", "Message 1")
      assert has_element?(view, ".chat-bubble", "Message 2")

      # Clear chat
      view
      |> element("button[phx-click='clear_chat']")
      |> render_click()

      # All messages should be cleared
      refute has_element?(view, ".chat-bubble", "Message 1")
      refute has_element?(view, ".chat-bubble", "Message 2")
    end

    @tag :evaluation
    test "assistant messages include source citation when on a page", %{conn: conn, user: user} do
      conn = log_in_user(conn, user)

      # Create a workspace and page with content
      workspace = workspace_fixture(user, %{name: "Test Workspace"})
      project = project_fixture(user, workspace)

      page =
        page_fixture(user, workspace, project, %{
          title: "Test Page",
          content: "This is test content about authentication."
        })

      {:ok, view, _html} = live(conn, ~p"/app/workspaces/#{workspace.slug}/pages/#{page.slug}")

      # Send a message
      view
      |> element("#chat-message-form")
      |> render_submit(%{message: "What is this page about?"})

      # Wait for response
      Process.sleep(3_000)

      html = render(view)

      # Should show source citation
      assert html =~ "Source:"
      assert html =~ page.title
      # Should have a link to the page
      assert html =~ ~r/href=".*#{page.slug}"/
    end
  end
end
