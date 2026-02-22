defmodule ExoDashboardWeb.BasicAuthTest do
  @moduledoc """
  Tests HTTP Basic Auth protection on the Exo Dashboard.

  Basic auth protects all routes except /health. Credentials are
  shared with LiveDashboard via :jarga app config.
  """
  use ExoDashboardWeb.ConnCase, async: false

  describe "basic auth on dashboard routes" do
    test "returns 503 when credentials are not configured" do
      Application.put_env(:jarga, :dashboard_username, nil)
      Application.put_env(:jarga, :dashboard_password, nil)

      conn = Phoenix.ConnTest.build_conn()
      conn = get(conn, "/")

      assert conn.status == 503
      assert conn.resp_body == "Dashboard authentication not configured"
    end

    test "returns 503 when only username is configured" do
      Application.put_env(:jarga, :dashboard_username, "admin")
      Application.put_env(:jarga, :dashboard_password, nil)

      conn = Phoenix.ConnTest.build_conn()
      conn = get(conn, "/")

      assert conn.status == 503
    end

    test "returns 503 when only password is configured" do
      Application.put_env(:jarga, :dashboard_username, nil)
      Application.put_env(:jarga, :dashboard_password, "secret")

      conn = Phoenix.ConnTest.build_conn()
      conn = get(conn, "/")

      assert conn.status == 503
    end

    test "returns 401 when no credentials are provided", %{conn: _conn} do
      conn = Phoenix.ConnTest.build_conn()
      conn = get(conn, "/")

      assert conn.status == 401
      assert get_resp_header(conn, "www-authenticate") != []
    end

    test "returns 401 with wrong password", %{conn: _conn} do
      credentials = Base.encode64("admin:wrong")

      conn =
        Phoenix.ConnTest.build_conn()
        |> put_req_header("authorization", "Basic #{credentials}")
        |> get("/")

      assert conn.status == 401
    end

    test "returns 401 with wrong username", %{conn: _conn} do
      credentials = Base.encode64("hacker:secret")

      conn =
        Phoenix.ConnTest.build_conn()
        |> put_req_header("authorization", "Basic #{credentials}")
        |> get("/")

      assert conn.status == 401
    end

    test "allows access with valid credentials", %{conn: conn} do
      conn = get(conn, "/")
      assert conn.status == 200
    end
  end

  describe "health endpoint bypasses basic auth" do
    test "returns 200 without credentials when auth is not configured" do
      Application.put_env(:jarga, :dashboard_username, nil)
      Application.put_env(:jarga, :dashboard_password, nil)

      conn = Phoenix.ConnTest.build_conn()
      conn = get(conn, "/health")

      assert conn.status == 200
      assert conn.resp_body == "ok"
    end

    test "returns 200 without credentials when auth is configured" do
      conn = Phoenix.ConnTest.build_conn()
      conn = get(conn, "/health")

      assert conn.status == 200
      assert conn.resp_body == "ok"
    end
  end
end
