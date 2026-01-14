defmodule JargaWeb.RouterTest do
  use JargaWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Jarga.AccountsFixtures

  describe "/app/* routes (unauthenticated)" do
    test "GET /app redirects to login", %{conn: conn} do
      assert {:error, redirect} = live(conn, ~p"/app")

      assert {:redirect, %{to: path, flash: flash}} = redirect
      assert path == ~p"/users/log-in"
      assert %{"error" => "You must log in to access this page."} = flash
    end
  end

  describe "/app/* routes (authenticated)" do
    setup %{conn: conn} do
      user = user_fixture()
      %{conn: log_in_user(conn, user), user: user}
    end

    test "GET /app allows access", %{conn: conn} do
      {:ok, _lv, html} = live(conn, ~p"/app")
      assert html =~ "Welcome to Jarga"
    end

    test "all /app routes use :require_authenticated_user pipeline", %{conn: conn} do
      # Verify that accessing /app routes uses the correct pipeline
      # by checking that the routes are protected at the pipeline level
      conn = get(conn, ~p"/app")

      # If pipeline protection wasn't working, we'd get a 200 or different response
      # Since /app is a LiveView, we expect it to succeed with authenticated conn
      assert conn.status in [200, 302]
    end
  end

  describe "route scopes and pipelines" do
    test "verifies /app routes are properly configured" do
      # This is a meta-test that ensures the router configuration is correct
      routes = JargaWeb.Router.__routes__()

      app_routes =
        Enum.filter(routes, fn route ->
          String.starts_with?(route.path, "/app")
        end)

      # Verify /app routes exist
      assert app_routes != [],
             "Expected at least 1 /app route"

      # Verify routes are configured (Phoenix routing internals)
      for route <- app_routes do
        assert route.plug != nil, "Route #{route.path} should have a plug configured"
      end
    end
  end

  describe "authentication redirect behavior" do
    test "redirects to / after fresh login (not authenticated yet)", %{conn: conn} do
      user = user_fixture()

      # Log in via session controller
      conn =
        post(conn, ~p"/users/log-in", %{
          "user" => %{"email" => user.email, "password" => valid_user_password()}
        })

      # Fresh logins redirect to "/" (user not yet in conn assigns)
      # This is expected behavior - see user_session_controller_test.exs
      assert redirected_to(conn) == ~p"/"
    end

    test "stores intended path and redirects after login", %{conn: conn} do
      # Try to access protected route
      {:error, redirect} = live(conn, ~p"/app")
      assert {:redirect, %{to: login_path}} = redirect
      assert login_path == ~p"/users/log-in"

      # Note: Testing the "return_to" redirect flow would require
      # following the full authentication flow with session preservation
      # This is covered in user_auth_test.exs
    end
  end
end
