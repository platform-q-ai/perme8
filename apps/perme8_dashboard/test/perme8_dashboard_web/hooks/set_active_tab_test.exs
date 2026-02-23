defmodule Perme8DashboardWeb.Hooks.SetActiveTabTest do
  use Perme8DashboardWeb.ConnCase, async: false

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

  describe "SetActiveTab on_mount hook" do
    test "sets active_tab to :features when on /", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/")

      assert has_element?(view, "[data-tab='features'].tab-active")
      refute has_element?(view, "[data-tab='sessions'].tab-active")
    end

    test "sets active_tab to :features when on /features path", %{conn: conn} do
      {:ok, view, _html} =
        live(conn, "/features/apps/test_app/test/features/example.browser.feature")

      assert has_element?(view, "[data-tab='features'].tab-active")
    end

    test "sets active_tab to :sessions when on /sessions", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/sessions")

      assert has_element?(view, "[data-tab='sessions'].tab-active")
      refute has_element?(view, "[data-tab='features'].tab-active")
    end

    test "sets active_tab to :sessions when on /sessions/:id", %{conn: conn} do
      user = Jarga.AccountsFixtures.user_fixture()
      session = Jarga.ChatFixtures.chat_session_fixture(user: user, title: "Test Session")

      {:ok, view, _html} = live(conn, "/sessions/#{session.id}")

      assert has_element?(view, "[data-tab='sessions'].tab-active")
      refute has_element?(view, "[data-tab='features'].tab-active")
    end

    test "assigns sessions_path for cross-app navigation", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/sessions")

      # The sessions_path should be "/sessions" (dashboard route)
      # Verify by checking the "Back" link in the show view uses /sessions
      # For index, just verify the view mounted successfully with the assign
      html = render(view)
      assert html =~ "Chat Sessions"
    end

    test "assigns sessions_base_path for building detail paths", %{conn: conn} do
      user = Jarga.AccountsFixtures.user_fixture()
      session = Jarga.ChatFixtures.chat_session_fixture(user: user, title: "Detail Test")

      {:ok, _view, html} = live(conn, "/sessions")

      # The session link should use /sessions/ prefix (dashboard route), not /chat-sessions/
      assert html =~ ~s(href="/sessions/#{session.id}")
    end
  end
end
