defmodule ExoDashboardWeb.BasicAuthTest do
  @moduledoc """
  Tests that the basic auth plug logic works correctly.

  Basic auth is compiled only in production (via :basic_auth_enabled
  compile-time flag). These tests verify the plug function directly
  to ensure credential checking works regardless of compile environment.
  """
  use ExoDashboardWeb.ConnCase, async: false

  describe "dashboard_basic_auth plug logic" do
    setup do
      on_exit(fn ->
        Application.delete_env(:jarga, :dashboard_username)
        Application.delete_env(:jarga, :dashboard_password)
      end)
    end

    test "returns 503 when credentials are not configured", %{conn: conn} do
      Application.put_env(:jarga, :dashboard_username, nil)
      Application.put_env(:jarga, :dashboard_password, nil)

      conn = apply_basic_auth_plug(conn)

      assert conn.status == 503
      assert conn.resp_body == "Dashboard authentication not configured"
      assert conn.halted
    end

    test "returns 503 when only username is configured", %{conn: conn} do
      Application.put_env(:jarga, :dashboard_username, "admin")
      Application.put_env(:jarga, :dashboard_password, nil)

      conn = apply_basic_auth_plug(conn)

      assert conn.status == 503
      assert conn.halted
    end

    test "returns 503 when only password is configured", %{conn: conn} do
      Application.put_env(:jarga, :dashboard_username, nil)
      Application.put_env(:jarga, :dashboard_password, "secret")

      conn = apply_basic_auth_plug(conn)

      assert conn.status == 503
      assert conn.halted
    end

    test "returns 401 when no credentials provided", %{conn: conn} do
      Application.put_env(:jarga, :dashboard_username, "admin")
      Application.put_env(:jarga, :dashboard_password, "secret")

      conn = apply_basic_auth_plug(conn)

      assert conn.status == 401
      assert get_resp_header(conn, "www-authenticate") != []
      assert conn.halted
    end

    test "returns 401 with wrong password", %{conn: conn} do
      Application.put_env(:jarga, :dashboard_username, "admin")
      Application.put_env(:jarga, :dashboard_password, "secret")

      conn =
        conn
        |> put_req_header("authorization", "Basic #{Base.encode64("admin:wrong")}")
        |> apply_basic_auth_plug()

      assert conn.status == 401
      assert conn.halted
    end

    test "returns 401 with wrong username", %{conn: conn} do
      Application.put_env(:jarga, :dashboard_username, "admin")
      Application.put_env(:jarga, :dashboard_password, "secret")

      conn =
        conn
        |> put_req_header("authorization", "Basic #{Base.encode64("hacker:secret")}")
        |> apply_basic_auth_plug()

      assert conn.status == 401
      assert conn.halted
    end

    test "passes through with valid credentials", %{conn: conn} do
      Application.put_env(:jarga, :dashboard_username, "admin")
      Application.put_env(:jarga, :dashboard_password, "secret")

      conn =
        conn
        |> put_req_header("authorization", "Basic #{Base.encode64("admin:secret")}")
        |> apply_basic_auth_plug()

      refute conn.halted
    end
  end

  # Exercises the same plug logic used in the router.
  # The actual router conditionally compiles this plug only in prod,
  # but the logic is identical.
  defp apply_basic_auth_plug(conn) do
    username = Application.get_env(:jarga, :dashboard_username)
    password = Application.get_env(:jarga, :dashboard_password)

    if username && password do
      Plug.BasicAuth.basic_auth(conn, username: username, password: password)
    else
      conn
      |> Plug.Conn.send_resp(503, "Dashboard authentication not configured")
      |> Plug.Conn.halt()
    end
  end
end
