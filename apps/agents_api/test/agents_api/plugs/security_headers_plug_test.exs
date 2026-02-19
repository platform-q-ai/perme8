defmodule AgentsApi.Plugs.SecurityHeadersPlugTest do
  use AgentsApi.ConnCase

  alias AgentsApi.Plugs.SecurityHeadersPlug

  describe "call/2" do
    test "sets x-content-type-options header", %{conn: conn} do
      conn = SecurityHeadersPlug.call(conn, [])
      assert get_resp_header(conn, "x-content-type-options") == ["nosniff"]
    end

    test "sets x-frame-options header", %{conn: conn} do
      conn = SecurityHeadersPlug.call(conn, [])
      assert get_resp_header(conn, "x-frame-options") == ["DENY"]
    end

    test "sets referrer-policy header", %{conn: conn} do
      conn = SecurityHeadersPlug.call(conn, [])
      assert get_resp_header(conn, "referrer-policy") == ["strict-origin-when-cross-origin"]
    end

    test "sets content-security-policy header", %{conn: conn} do
      conn = SecurityHeadersPlug.call(conn, [])
      assert get_resp_header(conn, "content-security-policy") == ["default-src 'none'"]
    end

    test "sets strict-transport-security header", %{conn: conn} do
      conn = SecurityHeadersPlug.call(conn, [])

      assert get_resp_header(conn, "strict-transport-security") == [
               "max-age=31536000; includeSubDomains"
             ]
    end

    test "sets permissions-policy header", %{conn: conn} do
      conn = SecurityHeadersPlug.call(conn, [])

      assert get_resp_header(conn, "permissions-policy") == [
               "camera=(), microphone=(), geolocation=()"
             ]
    end
  end
end
