defmodule Perme8DashboardWeb.SecurityTest do
  @moduledoc """
  Tests that the Perme8 Dashboard endpoint returns proper security headers.

  The `put_secure_browser_headers` plug in the router's browser pipeline
  sets these headers by default. In Phoenix 1.8+ this includes:
  - content-security-policy with frame-ancestors 'self' (replaces X-Frame-Options)
  - x-content-type-options: nosniff
  - referrer-policy: strict-origin-when-cross-origin
  """
  use Perme8DashboardWeb.ConnCase, async: true

  describe "security headers" do
    test "health endpoint returns X-Content-Type-Options nosniff", %{conn: conn} do
      conn = get(conn, "/health")

      assert get_resp_header(conn, "x-content-type-options") == ["nosniff"]
    end

    test "health endpoint returns content-security-policy with frame-ancestors", %{conn: conn} do
      conn = get(conn, "/health")

      [csp] = get_resp_header(conn, "content-security-policy")
      assert csp =~ "frame-ancestors 'self'"
    end

    test "health endpoint returns cache-control header", %{conn: conn} do
      conn = get(conn, "/health")

      assert [_ | _] = get_resp_header(conn, "cache-control")
    end
  end
end
