defmodule Perme8DashboardWeb.Live.FullFlowTest do
  @moduledoc """
  End-to-end flow tests that verify multi-step user journeys
  across multiple pages. Maps to BDD browser scenarios.

  These tests complement dashboard_live_test.exs by testing
  complete navigation flows rather than individual features.
  """
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
            Scenario.new(
              id: "s-2",
              name: "GET /users",
              keyword: "Scenario",
              steps: [
                Step.new(keyword: "Given ", text: "the API is running"),
                Step.new(keyword: "Then ", text: "I get a 200 response")
              ]
            )
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
              steps: [
                Step.new(keyword: "Given ", text: "a locked account"),
                Step.new(keyword: "Then ", text: "login attempts are rejected")
              ]
            )
          ]
        )
      ]
    },
    by_adapter: %{
      browser: [
        Feature.new(
          uri: "/apps/jarga_web/test/features/login.browser.feature",
          name: "Login",
          adapter: :browser,
          app: "jarga_web",
          children: []
        )
      ],
      http: [
        Feature.new(
          uri: "/apps/jarga_web/test/features/api.http.feature",
          name: "API Endpoints",
          adapter: :http,
          app: "jarga_web",
          children: []
        )
      ],
      security: [
        Feature.new(
          uri: "/apps/identity/test/features/auth.security.feature",
          name: "Auth Security",
          adapter: :security,
          app: "identity",
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

  describe "full flow: landing → filter → feature detail → back" do
    test "complete navigation journey through the dashboard", %{conn: conn} do
      # Step 1: Land on dashboard — see branding, active features tab, and feature tree
      {:ok, view, html} = live(conn, "/")

      assert html =~ "Perme8 Dashboard"
      assert has_element?(view, "[data-tab='features'].tab-active")
      assert has_element?(view, "[data-feature-tree]")
      assert has_element?(view, "[data-app='jarga_web']")
      assert has_element?(view, "[data-app='identity']")

      # Step 2: Filter to browser-only features
      html = view |> element("[data-filter='browser']") |> render_click()
      assert html =~ "Login"
      refute html =~ "Auth Security"
      refute html =~ "API Endpoints"

      # Step 3: Reset filter to all
      html = view |> element("[data-filter='all']") |> render_click()
      assert html =~ "Login"
      assert html =~ "Auth Security"
      assert html =~ "API Endpoints"

      # Step 4: Navigate to a feature detail page
      assert {:error, {:live_redirect, %{to: to}}} =
               view
               |> element("[data-feature='Login'] summary a")
               |> render_click()

      assert to =~ "/features/"

      # Step 5: Load the feature detail page and verify content
      {:ok, detail_view, _detail_html} = live(conn, to)
      detail_html = render(detail_view)

      assert detail_html =~ "data-feature-detail"
      assert detail_html =~ "Successful login"
      assert detail_html =~ "Given"
      assert detail_html =~ "Then"

      # Step 6: Navigate back to the feature list
      assert {:error, {:live_redirect, %{to: "/"}}} =
               detail_view |> element("a", "Back") |> render_click()
    end
  end

  describe "full flow: multiple filter toggles preserve state" do
    test "cycling through filters maintains correct feature visibility", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/")

      # Start: all features visible
      html = render(view)
      assert html =~ "Login"
      assert html =~ "API Endpoints"
      assert html =~ "Auth Security"

      # Toggle 1: Filter to browser only
      html = view |> element("[data-filter='browser']") |> render_click()
      assert html =~ "Login"
      refute html =~ "API Endpoints"
      refute html =~ "Auth Security"

      # Toggle 2: Reset to all
      html = view |> element("[data-filter='all']") |> render_click()
      assert html =~ "Login"
      assert html =~ "API Endpoints"
      assert html =~ "Auth Security"

      # Toggle 3: Filter to http only
      html = view |> element("[data-filter='http']") |> render_click()
      assert html =~ "API Endpoints"
      refute html =~ "Login"
      refute html =~ "Auth Security"

      # Toggle 4: Reset to all again
      html = view |> element("[data-filter='all']") |> render_click()
      assert html =~ "Login"
      assert html =~ "API Endpoints"
      assert html =~ "Auth Security"
    end
  end

  describe "full flow: feature detail shows scenarios with steps" do
    test "navigating to detail reveals scenario structure", %{conn: conn} do
      # Navigate to a feature with rich scenario data
      {:ok, view, _html} =
        live(conn, "/features/apps/jarga_web/test/features/login.browser.feature")

      html = render(view)

      # Verify feature detail container
      assert html =~ "data-feature-detail"

      # Verify scenario is shown
      assert html =~ "Successful login"

      # Verify step keywords are visible (BDD Given/When/Then structure)
      assert html =~ "Given"
      assert html =~ "When"
      assert html =~ "Then"

      # Verify actual step text is rendered
      assert html =~ "I am on the login page"
      assert html =~ "I enter valid credentials"
      assert html =~ "I am logged in"
    end
  end
end
