defmodule Perme8DashboardWeb.RouterTest do
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
              steps: [
                Step.new(keyword: "Given ", text: "a test step")
              ]
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

  describe "GET / (DashboardLive)" do
    test "renders DashboardLive content", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/")

      assert html =~ "Exo Dashboard"
    end

    test "uses Perme8 Dashboard layout", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/")

      assert html =~ "Perme8 Dashboard"
    end

    test "tab navigation is visible", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/")

      assert has_element?(view, "[data-tab='features']")
      assert has_element?(view, "[data-tab='sessions']")
    end
  end

  describe "GET /features/*uri (FeatureDetailLive)" do
    test "renders FeatureDetailLive content", %{conn: conn} do
      {:ok, view, _html} =
        live(conn, "/features/apps/test_app/test/features/example.browser.feature")

      # Wait for async load_features to complete
      html = render(view)
      assert html =~ "Example Feature"
    end

    test "uses Perme8 Dashboard layout on feature detail", %{conn: conn} do
      {:ok, _view, html} =
        live(conn, "/features/apps/test_app/test/features/example.browser.feature")

      assert html =~ "Perme8 Dashboard"
    end
  end

  describe "GET /sessions (requires auth)" do
    test "redirects unauthenticated users to Identity login", %{conn: conn} do
      conn = get(conn, "/sessions")

      assert redirected_to(conn) =~ "/users/log-in"
    end

    test "renders sessions page when authenticated", %{conn: conn} do
      %{conn: conn} = register_and_log_in_user(%{conn: conn})
      {:ok, _view, html} = live(conn, "/sessions")

      assert html =~ "Sessions"
      assert html =~ "Perme8 Dashboard"
    end
  end

  describe "GET /health" do
    test "health check still works outside live_session", %{conn: conn} do
      conn = get(conn, "/health")
      assert response(conn, 200) == "ok"
    end
  end
end
