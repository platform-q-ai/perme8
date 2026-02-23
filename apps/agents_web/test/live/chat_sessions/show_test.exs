defmodule AgentsWeb.ChatSessionsLive.ShowTest do
  use AgentsWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Jarga.AccountsFixtures
  import Jarga.ChatFixtures

  describe "mount and rendering" do
    setup %{conn: conn} do
      user = user_fixture()
      %{conn: log_in_user(conn, user), user: user}
    end

    test "mounts with session ID and loads session with messages", %{conn: conn, user: user} do
      session = chat_session_fixture(user: user, title: "My Chat")
      chat_message_fixture(chat_session_id: session.id, role: "user", content: "Hello!")
      chat_message_fixture(chat_session_id: session.id, role: "assistant", content: "Hi there!")

      {:ok, _lv, html} = live(conn, ~p"/chat-sessions/#{session.id}")

      assert html =~ "My Chat"
      assert html =~ "Hello!"
      assert html =~ "Hi there!"
    end

    test "displays session title in heading", %{conn: conn, user: user} do
      session = chat_session_fixture(user: user, title: "Important Discussion")

      {:ok, _lv, html} = live(conn, ~p"/chat-sessions/#{session.id}")

      assert html =~ "Important Discussion"
    end

    test "renders messages using message component with data attributes", %{
      conn: conn,
      user: user
    } do
      session = chat_session_fixture(user: user, title: "Test")
      chat_message_fixture(chat_session_id: session.id, role: "user", content: "Question?")

      {:ok, _lv, html} = live(conn, ~p"/chat-sessions/#{session.id}")

      assert html =~ "data-session-message"
      assert html =~ ~s(data-message-role="user")
      assert html =~ "data-message-content"
    end

    test "messages are in chronological order", %{conn: conn, user: user} do
      session = chat_session_fixture(user: user, title: "Ordered")
      chat_message_fixture(chat_session_id: session.id, role: "user", content: "First message")

      chat_message_fixture(
        chat_session_id: session.id,
        role: "assistant",
        content: "Second message"
      )

      {:ok, _lv, html} = live(conn, ~p"/chat-sessions/#{session.id}")

      # First message should appear before second in the HTML
      first_pos = :binary.match(html, "First message") |> elem(0)
      second_pos = :binary.match(html, "Second message") |> elem(0)
      assert first_pos < second_pos
    end

    test "has data-session-detail container", %{conn: conn, user: user} do
      session = chat_session_fixture(user: user, title: "Detail View")

      {:ok, _lv, html} = live(conn, ~p"/chat-sessions/#{session.id}")

      assert html =~ "data-session-detail"
    end

    test "has back link to /chat-sessions", %{conn: conn, user: user} do
      session = chat_session_fixture(user: user, title: "Back Test")

      {:ok, lv, html} = live(conn, ~p"/chat-sessions/#{session.id}")

      assert html =~ "Back"
      assert has_element?(lv, ~s(a[href="/chat-sessions"]))
    end

    test "redirects when session not found", %{conn: conn} do
      fake_id = Ecto.UUID.generate()

      assert {:error, {:redirect, %{to: "/chat-sessions"}}} =
               live(conn, ~p"/chat-sessions/#{fake_id}")
    end

    test "sets page title to session title", %{conn: conn, user: user} do
      session = chat_session_fixture(user: user, title: "Title Test")

      {:ok, lv, _html} = live(conn, ~p"/chat-sessions/#{session.id}")

      assert page_title(lv) =~ "Title Test"
    end

    test "handles session without title", %{conn: conn, user: user} do
      session = chat_session_fixture(user: user)

      {:ok, _lv, html} = live(conn, ~p"/chat-sessions/#{session.id}")

      assert html =~ "Untitled Session"
    end
  end
end
