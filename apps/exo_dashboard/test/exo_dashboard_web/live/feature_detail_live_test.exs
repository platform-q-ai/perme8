defmodule ExoDashboardWeb.FeatureDetailLiveTest do
  use ExoDashboardWeb.ConnCase, async: false

  alias ExoDashboard.Features.Domain.Entities.{Feature, Scenario, Step, Rule}

  @feature Feature.new(
             uri: "apps/jarga_web/test/features/login.browser.feature",
             name: "Login Feature",
             description: "User login functionality",
             adapter: :browser,
             app: "jarga_web",
             tags: ["@auth"],
             children: [
               Scenario.new(
                 id: "s-1",
                 name: "Successful login",
                 keyword: "Scenario",
                 steps: [
                   Step.new(keyword: "Given ", text: "I am on the login page"),
                   Step.new(keyword: "When ", text: "I enter valid credentials"),
                   Step.new(keyword: "Then ", text: "I should be logged in")
                 ]
               ),
               Rule.new(
                 id: "r-1",
                 name: "Password Validation",
                 children: [
                   Scenario.new(
                     id: "s-2",
                     name: "Short password rejected",
                     keyword: "Scenario",
                     steps: [
                       Step.new(keyword: "Given ", text: "I am on registration"),
                       Step.new(keyword: "When ", text: "I enter password 'ab'"),
                       Step.new(keyword: "Then ", text: "I see an error")
                     ]
                   )
                 ]
               )
             ]
           )

  @mock_catalog %{
    apps: %{
      "jarga_web" => [@feature]
    },
    by_adapter: %{
      browser: [@feature]
    }
  }

  setup do
    Application.put_env(:exo_dashboard, :test_catalog, @mock_catalog)
    on_exit(fn -> Application.delete_env(:exo_dashboard, :test_catalog) end)
    :ok
  end

  describe "GET /features/*uri" do
    test "renders feature detail page", %{conn: conn} do
      {:ok, _view, html} =
        live(conn, ~p"/features/apps/jarga_web/test/features/login.browser.feature")

      assert html =~ "Login Feature"
    end

    test "shows feature name and description", %{conn: conn} do
      {:ok, _view, html} =
        live(conn, ~p"/features/apps/jarga_web/test/features/login.browser.feature")

      assert html =~ "Login Feature"
    end

    test "shows scenarios with steps", %{conn: conn} do
      {:ok, _view, html} =
        live(conn, ~p"/features/apps/jarga_web/test/features/login.browser.feature")

      assert html =~ "Successful login"
      assert html =~ "I am on the login page"
      assert html =~ "I enter valid credentials"
      assert html =~ "I should be logged in"
    end

    test "shows Rules as sections", %{conn: conn} do
      {:ok, _view, html} =
        live(conn, ~p"/features/apps/jarga_web/test/features/login.browser.feature")

      assert html =~ "Password Validation"
      assert html =~ "Short password rejected"
    end

    test "shows back link to dashboard", %{conn: conn} do
      {:ok, _view, html} =
        live(conn, ~p"/features/apps/jarga_web/test/features/login.browser.feature")

      assert html =~ "Back"
    end
  end
end
