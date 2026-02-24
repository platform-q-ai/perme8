defmodule Perme8DashboardWeb.Live.SessionsTabTest do
  @moduledoc """
  Integration tests for the Sessions tab in the Perme8 Dashboard.

  Verifies that AgentsWeb.SessionsLive.Index is correctly mounted
  in the dashboard router with Identity auth, and renders within
  the dashboard layout.
  """
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

  describe "GET /sessions (unauthenticated)" do
    test "redirects to Identity login page", %{conn: conn} do
      conn = get(conn, "/sessions")

      assert redirected_to(conn) =~ "/users/log-in"
      assert redirected_to(conn) =~ "return_to="
    end
  end

  describe "GET /sessions (authenticated)" do
    setup :register_and_log_in_user

    test "renders sessions content within dashboard layout", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/sessions")

      # Dashboard layout present
      assert html =~ "Perme8 Dashboard"
      # Sessions content present (AgentsWeb.SessionsLive.Index renders "Sessions" header)
      assert html =~ "Sessions"
    end

    test "sessions sidebar link is marked active", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/sessions")

      assert has_element?(view, "[data-sidebar-sessions] a.active")
      refute has_element?(view, "[data-sidebar-features] a.active")
    end

    test "dashboard sidebar is visible", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/sessions")

      assert html =~ "drawer-side"
      assert html =~ "data-sidebar-sessions"
    end
  end

  describe "features tab still works without auth" do
    test "features page renders without authentication", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/")

      assert has_element?(view, "[data-sidebar-features] a.active")
    end

    test "both sidebar links display correct labels", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/")

      assert html =~ "Features"
      assert html =~ "Sessions"
    end

    test "sessions sidebar link is visible on features page", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/")

      assert has_element?(view, "[data-sidebar-sessions]")
    end
  end
end
