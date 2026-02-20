defmodule ExoDashboardWeb.DashboardLiveTest do
  use ExoDashboardWeb.ConnCase, async: false

  alias ExoDashboard.Features.Domain.Entities.{Feature, Scenario, Step}

  @mock_catalog %{
    apps: %{
      "jarga_web" => [
        Feature.new(
          uri: "apps/jarga_web/test/features/login.browser.feature",
          name: "Login",
          adapter: :browser,
          app: "jarga_web",
          children: [
            Scenario.new(
              id: "s-1",
              name: "Successful login",
              keyword: "Scenario",
              steps: [
                Step.new(keyword: "Given ", text: "I am on the login page"),
                Step.new(keyword: "When ", text: "I enter valid credentials"),
                Step.new(keyword: "Then ", text: "I am logged in")
              ]
            )
          ]
        ),
        Feature.new(
          uri: "apps/jarga_web/test/features/api.http.feature",
          name: "API Endpoints",
          adapter: :http,
          app: "jarga_web",
          children: [
            Scenario.new(id: "s-2", name: "GET /users", keyword: "Scenario", steps: [])
          ]
        )
      ],
      "identity" => [
        Feature.new(
          uri: "apps/identity/test/features/auth.security.feature",
          name: "Auth Security",
          adapter: :security,
          app: "identity",
          children: [
            Scenario.new(
              id: "s-3",
              name: "Brute force protection",
              keyword: "Scenario",
              steps: []
            )
          ]
        )
      ]
    },
    by_adapter: %{
      browser: [Feature.new(name: "Login", adapter: :browser, app: "jarga_web", children: [])],
      http: [Feature.new(name: "API Endpoints", adapter: :http, app: "jarga_web", children: [])],
      security: [
        Feature.new(name: "Auth Security", adapter: :security, app: "identity", children: [])
      ]
    }
  }

  defp mock_discover_module do
    # Use Application env to inject mock
    Application.put_env(:exo_dashboard, :test_catalog, @mock_catalog)
    on_exit(fn -> Application.delete_env(:exo_dashboard, :test_catalog) end)
  end

  describe "GET /" do
    setup do
      mock_discover_module()
      :ok
    end

    test "mounts and renders the dashboard", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/")

      assert html =~ "Exo Dashboard"
    end

    test "shows feature list grouped by app", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/")

      assert html =~ "jarga_web"
      assert html =~ "identity"
      assert html =~ "Login"
      assert html =~ "API Endpoints"
      assert html =~ "Auth Security"
    end

    test "shows adapter badges", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/")

      assert html =~ "Browser"
      assert html =~ "HTTP"
      assert html =~ "Security"
    end

    test "shows scenario counts", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/")

      assert html =~ "1 scenario"
    end
  end

  describe "filter event" do
    setup do
      mock_discover_module()
      :ok
    end

    test "filters by adapter", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")

      html = view |> element("[data-filter=browser]") |> render_click()

      assert html =~ "Login"
      refute html =~ "Auth Security"
    end

    test "shows all when filter is cleared", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")

      # Apply a filter
      view |> element("[data-filter=browser]") |> render_click()

      # Clear the filter
      html = view |> element("[data-filter=all]") |> render_click()

      assert html =~ "Login"
      assert html =~ "Auth Security"
    end
  end

  describe "refresh event" do
    setup do
      mock_discover_module()
      :ok
    end

    test "re-discovers features on refresh click", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")

      # Click refresh - should re-render without error
      html = view |> element("[data-action=refresh]") |> render_click()

      assert html =~ "Login"
    end
  end
end
