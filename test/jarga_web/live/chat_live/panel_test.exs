defmodule JargaWeb.ChatLive.PanelTest do
  use JargaWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Jarga.AccountsFixtures

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

    @tag :integration
    test "displays assistant response", %{conn: conn, user: user} do
      conn = log_in_user(conn, user)

      {:ok, view, _html} = live(conn, ~p"/app")

      view
      |> element("#chat-message-form")
      |> render_submit(%{message: "What is 2+2?"})

      # Wait for response (this will actually call the LLM in integration tests)
      assert_receive {:assistant_response, response}, 10_000

      # Should show assistant response in chat bubbles (chat-start is for assistant)
      assert has_element?(view, ".chat.chat-start .chat-bubble", response)
    end

    @tag :integration
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

    @tag :integration
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

    @tag :integration
    test "shows streaming indicator with cursor while receiving response", %{conn: conn, user: user} do
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
end
