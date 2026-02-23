defmodule Perme8DashboardWeb.Live.ChatSessionsTabTest do
  @moduledoc """
  Integration tests for the Sessions tab in the Perme8 Dashboard.

  Verifies that AgentsWeb.ChatSessionsLive.Index and Show are correctly
  mounted in the dashboard router and render within the dashboard layout.
  """
  use Perme8DashboardWeb.ConnCase, async: false

  import Jarga.AccountsFixtures
  import Jarga.ChatFixtures

  alias ExoDashboard.Features.Domain.Entities.{Feature, Scenario, Step}

  @mock_catalog %{
    apps: %{
      "test_app" => [
        Feature.new(
          uri: "/apps/test_app/test/features/example.browser.feature",
          name: "Example Feature",
          adapter: :browser,
          app: "test_app",
          children: [
            Scenario.new(
              id: "s-1",
              name: "Basic scenario",
              keyword: "Scenario",
              steps: [Step.new(keyword: "Given ", text: "a test step")]
            )
          ]
        )
      ]
    },
    by_adapter: %{
      browser: [
        Feature.new(
          name: "Example Feature",
          adapter: :browser,
          app: "test_app",
          children: []
        )
      ]
    }
  }

  setup do
    Application.put_env(:exo_dashboard, :test_catalog, @mock_catalog)
    on_exit(fn -> Application.delete_env(:exo_dashboard, :test_catalog) end)
    :ok
  end

  describe "GET /sessions (ChatSessionsLive.Index)" do
    test "renders sessions content within dashboard layout", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/sessions")

      # Dashboard layout present
      assert html =~ "Perme8 Dashboard"
      # Sessions content present
      assert html =~ "Chat Sessions"
    end

    test "renders session list when sessions exist", %{conn: conn} do
      user = user_fixture()
      chat_session_fixture(user: user, title: "Dashboard Session 1")
      chat_session_fixture(user: user, title: "Dashboard Session 2")

      {:ok, _view, html} = live(conn, "/sessions")

      assert html =~ "Dashboard Session 1"
      assert html =~ "Dashboard Session 2"
    end

    test "shows empty state when no sessions", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/sessions")

      assert html =~ "data-empty-state"
    end

    test "sessions tab is marked active", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/sessions")

      assert has_element?(view, "[data-tab='sessions'].tab-active")
      refute has_element?(view, "[data-tab='features'].tab-active")
    end

    test "dashboard sidebar is visible", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/sessions")

      assert html =~ "drawer-side"
      assert html =~ "data-sidebar-sessions"
    end

    test "session links use /sessions/ prefix (dashboard route)", %{conn: conn} do
      user = user_fixture()
      session = chat_session_fixture(user: user, title: "Link Test")

      {:ok, _view, html} = live(conn, "/sessions")

      assert html =~ ~s(href="/sessions/#{session.id}")
      refute html =~ "/chat-sessions/"
    end

    test "has data-session-list container", %{conn: conn} do
      user = user_fixture()
      chat_session_fixture(user: user, title: "A session")

      {:ok, _view, html} = live(conn, "/sessions")

      assert html =~ "data-session-list"
    end

    test "has data-session attributes", %{conn: conn} do
      user = user_fixture()
      session = chat_session_fixture(user: user, title: "Data Attr Test")

      {:ok, _view, html} = live(conn, "/sessions")

      assert html =~ ~s(data-session="#{session.id}")
    end
  end

  describe "GET /sessions/:id (ChatSessionsLive.Show)" do
    test "renders session detail within dashboard layout", %{conn: conn} do
      user = user_fixture()
      session = chat_session_fixture(user: user, title: "Detail in Dashboard")
      chat_message_fixture(chat_session_id: session.id, role: "user", content: "Hello from test")

      {:ok, _view, html} = live(conn, "/sessions/#{session.id}")

      # Dashboard layout present
      assert html =~ "Perme8 Dashboard"
      # Session content present
      assert html =~ "Detail in Dashboard"
      assert html =~ "Hello from test"
    end

    test "sessions tab is active on detail page", %{conn: conn} do
      user = user_fixture()
      session = chat_session_fixture(user: user, title: "Active Tab Detail")

      {:ok, view, _html} = live(conn, "/sessions/#{session.id}")

      assert has_element?(view, "[data-tab='sessions'].tab-active")
      refute has_element?(view, "[data-tab='features'].tab-active")
    end

    test "back link navigates to /sessions (dashboard route)", %{conn: conn} do
      user = user_fixture()
      session = chat_session_fixture(user: user, title: "Back Link Test")

      {:ok, view, _html} = live(conn, "/sessions/#{session.id}")

      assert has_element?(view, ~s(a[href="/sessions"]))
    end

    test "has data-session-detail container", %{conn: conn} do
      user = user_fixture()
      session = chat_session_fixture(user: user, title: "Detail Container")

      {:ok, _view, html} = live(conn, "/sessions/#{session.id}")

      assert html =~ "data-session-detail"
    end

    test "has data-session-message elements", %{conn: conn} do
      user = user_fixture()
      session = chat_session_fixture(user: user, title: "Messages Test")
      chat_message_fixture(chat_session_id: session.id, role: "user", content: "Test msg")

      {:ok, _view, html} = live(conn, "/sessions/#{session.id}")

      assert html =~ "data-session-message"
      assert html =~ ~s(data-message-role="user")
    end

    test "redirects when session not found", %{conn: conn} do
      fake_id = Ecto.UUID.generate()

      assert {:error, {:redirect, %{to: "/sessions"}}} =
               live(conn, "/sessions/#{fake_id}")
    end
  end

  describe "tab navigation between Features and Sessions" do
    test "features tab is active on landing page", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/")

      assert has_element?(view, "[data-tab='features'].tab-active")
      refute has_element?(view, "[data-tab='sessions'].tab-active")
    end

    test "sessions tab is visible on features page", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/")

      assert has_element?(view, "[data-tab='sessions']")
    end

    test "features tab is visible on sessions page", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/sessions")

      assert has_element?(view, "[data-tab='features']")
    end

    test "both tabs display correct labels", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/")

      assert html =~ "Features"
      assert html =~ "Sessions"
    end
  end

  describe "session deletion in dashboard context" do
    test "deleting a session removes it from the list", %{conn: conn} do
      user = user_fixture()
      session = chat_session_fixture(user: user, title: "Delete Me Dashboard")

      {:ok, lv, html} = live(conn, "/sessions")
      assert html =~ "Delete Me Dashboard"

      lv
      |> element(~s([data-session-delete][phx-value-id="#{session.id}"]))
      |> render_click()

      html = render(lv)
      refute html =~ "Delete Me Dashboard"
    end
  end
end
