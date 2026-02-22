defmodule Perme8DashboardWeb.Live.DashboardLiveTest do
  use Perme8DashboardWeb.ConnCase, async: false

  alias ExoDashboard.Features.Domain.Entities.{Feature, Scenario, Step}

  @mock_catalog %{
    apps: %{
      "jarga_web" => [
        Feature.new(
          uri: "/apps/jarga_web/test/features/login.browser.feature",
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
          uri: "/apps/jarga_web/test/features/api.http.feature",
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
          uri: "/apps/identity/test/features/auth.security.feature",
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
      browser: [
        Feature.new(name: "Login", adapter: :browser, app: "jarga_web", children: [])
      ],
      http: [
        Feature.new(name: "API Endpoints", adapter: :http, app: "jarga_web", children: [])
      ],
      security: [
        Feature.new(name: "Auth Security", adapter: :security, app: "identity", children: [])
      ]
    }
  }

  setup do
    Application.put_env(:exo_dashboard, :test_catalog, @mock_catalog)
    on_exit(fn -> Application.delete_env(:exo_dashboard, :test_catalog) end)
    :ok
  end

  describe "dashboard layout integration" do
    test "renders Perme8 Dashboard branding in layout", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/")

      assert html =~ "Perme8 Dashboard"
    end

    test "renders features tab as active", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/")

      assert has_element?(view, "[data-tab='features']")
      assert has_element?(view, "[data-tab='features'].tab-active")
    end

    test "renders feature tree on landing", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/")

      assert has_element?(view, "[data-feature-tree]")
    end

    test "dark theme attributes present", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/")

      assert html =~ ~s(data-theme="dark")
      assert html =~ "bg-base-100"
    end
  end

  describe "feature tree display" do
    test "displays app groups", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/")

      assert has_element?(view, "[data-app='jarga_web']")
      assert has_element?(view, "[data-app='identity']")
    end

    test "displays feature and scenario counts", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/")
      html = render(view)

      assert html =~ "feature"
      assert html =~ "scenario"
    end

    test "displays filter buttons", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/")

      assert has_element?(view, "[data-filter='all']")
      assert has_element?(view, "[data-filter='browser']")
      assert has_element?(view, "[data-filter='http']")
      assert has_element?(view, "[data-filter='security']")
    end
  end

  describe "filtering" do
    test "filtering by adapter shows matching features", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/")

      html = view |> element("[data-filter='browser']") |> render_click()

      assert html =~ "Login"
      refute html =~ "Auth Security"
    end

    test "all filter resets features", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/")

      # First filter to browser only
      view |> element("[data-filter='browser']") |> render_click()
      # Then reset with all
      html = view |> element("[data-filter='all']") |> render_click()

      assert html =~ "Login"
      assert html =~ "Auth Security"
    end
  end

  describe "data attributes for BDD selectors" do
    test "data-feature-tree exists on dashboard", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/")

      assert has_element?(view, "[data-feature-tree]")
    end

    test "data-feature-detail exists on feature detail", %{conn: conn} do
      {:ok, view, _html} =
        live(conn, "/features/apps/jarga_web/test/features/login.browser.feature")

      # Wait for async load
      html = render(view)
      assert html =~ "data-feature-detail"
    end

    test "data-app attributes exist on app groups", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/")

      assert has_element?(view, "[data-app]")
    end

    test "data-feature attributes exist on feature elements", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/")

      assert has_element?(view, "[data-feature]")
    end

    test "data-adapter attributes exist on adapter badges", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/")

      assert has_element?(view, "[data-adapter]")
    end

    test "data-filter attributes exist on filter buttons", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/")

      assert has_element?(view, "[data-filter]")
    end
  end

  describe "feature detail navigation" do
    test "clicking feature navigates to detail", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/")

      # Click on the feature name link (navigate within same live_session = live_redirect)
      assert {:error, {:live_redirect, %{to: to}}} =
               view
               |> element("[data-feature='Login'] summary a")
               |> render_click()

      assert to =~ "/features/"
    end

    test "feature detail shows scenarios and steps", %{conn: conn} do
      {:ok, view, _html} =
        live(conn, "/features/apps/jarga_web/test/features/login.browser.feature")

      html = render(view)

      assert html =~ "Successful login"
      assert html =~ "Given"
      assert html =~ "Then"
    end

    test "back navigation returns to list", %{conn: conn} do
      {:ok, view, _html} =
        live(conn, "/features/apps/jarga_web/test/features/login.browser.feature")

      # The back link triggers a live redirect (navigate within same live_session)
      assert {:error, {:live_redirect, %{to: "/"}}} =
               view |> element("a", "Back") |> render_click()
    end
  end
end
