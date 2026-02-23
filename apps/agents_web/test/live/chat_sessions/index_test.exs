defmodule AgentsWeb.ChatSessionsLive.IndexTest do
  use AgentsWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Jarga.AccountsFixtures
  import Jarga.ChatFixtures

  describe "mount and rendering" do
    setup %{conn: conn} do
      user = user_fixture()
      %{conn: log_in_user(conn, user), user: user}
    end

    test "renders the chat sessions page with heading", %{conn: conn} do
      {:ok, _lv, html} = live(conn, ~p"/chat-sessions")
      assert html =~ "Chat Sessions"
    end

    test "sets page title", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/chat-sessions")
      assert page_title(lv) =~ "Chat Sessions"
    end

    test "lists all chat sessions", %{conn: conn, user: user} do
      _session1 = chat_session_fixture(user: user, title: "First chat")
      _session2 = chat_session_fixture(user: user, title: "Second chat")

      {:ok, _lv, html} = live(conn, ~p"/chat-sessions")
      assert html =~ "First chat"
      assert html =~ "Second chat"
    end

    test "displays session title, message count, and timestamp", %{conn: conn, user: user} do
      session = chat_session_fixture(user: user, title: "My Session")
      chat_message_fixture(chat_session_id: session.id, role: "user", content: "Hello")
      chat_message_fixture(chat_session_id: session.id, role: "assistant", content: "Hi there")

      {:ok, _lv, html} = live(conn, ~p"/chat-sessions")

      assert html =~ "My Session"
      assert html =~ "data-session-title"
      assert html =~ "data-session-message-count"
      assert html =~ "data-session-timestamp"
    end

    test "shows empty state when no sessions exist", %{conn: conn} do
      {:ok, _lv, html} = live(conn, ~p"/chat-sessions")
      assert html =~ "data-empty-state"
      refute html =~ "data-session\""
    end

    test "each session has data-session attribute", %{conn: conn, user: user} do
      chat_session_fixture(user: user, title: "A session")

      {:ok, _lv, html} = live(conn, ~p"/chat-sessions")
      assert html =~ "data-session"
    end

    test "has data-session-list container", %{conn: conn, user: user} do
      chat_session_fixture(user: user, title: "A session")

      {:ok, _lv, html} = live(conn, ~p"/chat-sessions")
      assert html =~ "data-session-list"
    end
  end

  describe "navigation" do
    setup %{conn: conn} do
      user = user_fixture()
      %{conn: log_in_user(conn, user), user: user}
    end

    test "clicking a session navigates to show view", %{conn: conn, user: user} do
      session = chat_session_fixture(user: user, title: "Navigate me")

      {:ok, lv, _html} = live(conn, ~p"/chat-sessions")

      lv
      |> element(~s([data-session="#{session.id}"] a), "Navigate me")
      |> render_click()

      assert_redirect(lv, ~p"/chat-sessions/#{session.id}")
    end
  end

  describe "delete session" do
    setup %{conn: conn} do
      user = user_fixture()
      %{conn: log_in_user(conn, user), user: user}
    end

    test "each session has a delete button", %{conn: conn, user: user} do
      chat_session_fixture(user: user, title: "Deletable session")

      {:ok, _lv, html} = live(conn, ~p"/chat-sessions")
      assert html =~ "data-session-delete"
    end

    test "deleting a session removes it from the list", %{conn: conn, user: user} do
      session = chat_session_fixture(user: user, title: "Delete me")

      {:ok, lv, html} = live(conn, ~p"/chat-sessions")
      assert html =~ "Delete me"

      lv
      |> element(~s([data-session-delete][phx-value-id="#{session.id}"]))
      |> render_click()

      html = render(lv)
      refute html =~ "Delete me"
    end
  end
end
