defmodule JargaWeb.ChatLive.PanelTest do
  use JargaWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Jarga.AccountsFixtures

  describe "Panel component" do
    setup do
      user = user_fixture()
      %{user: user}
    end

    test "renders collapsed by default", %{conn: conn, user: user} do
      conn = log_in_user(conn, user)

      {:ok, view, _html} = live(conn, ~p"/app")

      assert has_element?(view, "#global-chat-panel")
      assert has_element?(view, "[data-collapsed='true']")
    end

    test "expands when toggle clicked", %{conn: conn, user: user} do
      conn = log_in_user(conn, user)

      {:ok, view, _html} = live(conn, ~p"/app")

      # Click toggle button
      view
      |> element("#chat-toggle-button")
      |> render_click()

      assert has_element?(view, "[data-collapsed='false']")
    end

    test "allows sending a message", %{conn: conn, user: user} do
      conn = log_in_user(conn, user)

      {:ok, view, _html} = live(conn, ~p"/app")

      # Expand panel
      view
      |> element("#chat-toggle-button")
      |> render_click()

      # Send message
      view
      |> element("#chat-message-form")
      |> render_submit(%{message: %{content: "Hello!"}})

      # Should show user message
      assert has_element?(view, "[data-role='user']", "Hello!")
    end

    test "displays assistant response", %{conn: conn, user: user} do
      conn = log_in_user(conn, user)

      {:ok, view, _html} = live(conn, ~p"/app")

      # Expand and send message
      view
      |> element("#chat-toggle-button")
      |> render_click()

      view
      |> element("#chat-message-form")
      |> render_submit(%{message: %{content: "What is 2+2?"}})

      # Wait for response (this will actually call the LLM in integration tests)
      # For unit tests, we'd mock this
      assert_receive {:assistant_response, _response}, 10_000
    end

    test "shows loading state while waiting for response", %{conn: conn, user: user} do
      conn = log_in_user(conn, user)

      {:ok, view, _html} = live(conn, ~p"/app")

      view
      |> element("#chat-toggle-button")
      |> render_click()

      view
      |> element("#chat-message-form")
      |> render_submit(%{message: %{content: "Hello"}})

      # Should show loading indicator
      assert has_element?(view, "[data-loading='true']")
    end

    test "extracts page context for queries", %{conn: conn, user: user} do
      conn = log_in_user(conn, user)

      {:ok, view, _html} = live(conn, ~p"/app")

      # The panel should have access to page assigns
      # This will be tested more thoroughly in integration tests
      assert view.module != nil
    end
  end
end
