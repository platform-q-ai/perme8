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

      assert has_element?(view, "[data-sidebar-features] a.active")
      refute has_element?(view, "[data-sidebar-sessions] a.active")
    end

    test "sets active_tab to :features when on /features path", %{conn: conn} do
      {:ok, view, _html} =
        live(conn, "/features/apps/test_app/test/features/example.browser.feature")

      assert has_element?(view, "[data-sidebar-features] a.active")
    end

    test "sets active_tab to :sessions when on /sessions (authenticated)", %{conn: conn} do
      %{conn: conn} = register_and_log_in_user(%{conn: conn})
      {:ok, view, _html} = live(conn, "/sessions")

      assert has_element?(view, "[data-sidebar-sessions] a.active")
      refute has_element?(view, "[data-sidebar-features] a.active")
    end

    test "assigns sessions_path for cross-app navigation", %{conn: conn} do
      %{conn: conn} = register_and_log_in_user(%{conn: conn})
      {:ok, _view, html} = live(conn, "/sessions")

      # Sessions content present (AgentsWeb.SessionsLive.Index renders "Sessions" header)
      assert html =~ "Sessions"
    end
  end
end
