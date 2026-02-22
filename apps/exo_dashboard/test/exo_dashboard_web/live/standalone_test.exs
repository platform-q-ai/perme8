defmodule ExoDashboardWeb.StandaloneLiveTest do
  @moduledoc """
  Verifies the exo_dashboard standalone experience still works after
  layout migration (drawer removed, minimal app layout).
  """
  use ExoDashboardWeb.ConnCase, async: false

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
        )
      ]
    },
    by_adapter: %{
      browser: [
        Feature.new(name: "Login", adapter: :browser, app: "jarga_web", children: [])
      ]
    }
  }

  setup do
    Application.put_env(:exo_dashboard, :test_catalog, @mock_catalog)
    on_exit(fn -> Application.delete_env(:exo_dashboard, :test_catalog) end)
    :ok
  end

  describe "standalone exo_dashboard" do
    test "dashboard loads on exo endpoint", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/")

      assert html =~ "Exo Dashboard"
    end

    test "content renders without drawer", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/")

      refute html =~ "drawer"
    end

    test "feature list is functional", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")
      html = render(view)

      assert html =~ "Login"
      assert html =~ "jarga_web"
    end

    test "navigation to feature detail works", %{conn: conn} do
      {:ok, view, _html} =
        live(conn, ~p"/features/apps/jarga_web/test/features/login.browser.feature")

      html = render(view)

      assert html =~ "Login"
      assert html =~ "Successful login"
    end

    test "back navigation works", %{conn: conn} do
      {:ok, view, _html} =
        live(conn, ~p"/features/apps/jarga_web/test/features/login.browser.feature")

      assert {:error, {:live_redirect, %{to: "/"}}} =
               view |> element("a", "Back") |> render_click()
    end
  end
end
