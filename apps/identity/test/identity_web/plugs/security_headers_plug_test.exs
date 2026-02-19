defmodule IdentityWeb.Plugs.SecurityHeadersPlugTest do
  use ExUnit.Case, async: true

  import Plug.Conn
  import Plug.Test

  alias IdentityWeb.Plugs.SecurityHeadersPlug

  describe "call/2" do
    setup do
      conn = conn(:get, "/") |> SecurityHeadersPlug.call([])
      %{conn: conn}
    end

    test "sets X-Content-Type-Options to nosniff", %{conn: conn} do
      assert get_resp_header(conn, "x-content-type-options") == ["nosniff"]
    end

    test "sets X-Frame-Options to DENY", %{conn: conn} do
      assert get_resp_header(conn, "x-frame-options") == ["DENY"]
    end

    test "sets Referrer-Policy to strict-origin-when-cross-origin", %{conn: conn} do
      assert get_resp_header(conn, "referrer-policy") == ["strict-origin-when-cross-origin"]
    end

    test "sets Strict-Transport-Security with max-age and includeSubDomains", %{conn: conn} do
      assert get_resp_header(conn, "strict-transport-security") == [
               "max-age=31536000; includeSubDomains"
             ]
    end

    test "sets Permissions-Policy restricting camera, microphone, and geolocation", %{conn: conn} do
      assert get_resp_header(conn, "permissions-policy") == [
               "camera=(), microphone=(), geolocation=()"
             ]
    end

    test "sets Content-Security-Policy with all required directives", %{conn: conn} do
      [csp] = get_resp_header(conn, "content-security-policy")

      assert csp =~ "default-src 'self'"
      assert csp =~ "script-src 'self' 'unsafe-inline'"
      assert csp =~ "style-src 'self' 'unsafe-inline'"
      assert csp =~ "img-src 'self' data:"
      assert csp =~ "font-src 'self'"
      assert csp =~ "connect-src 'self'"
      assert csp =~ "frame-ancestors 'none'"
      assert csp =~ "form-action 'self'"
      assert csp =~ "base-uri 'self'"
      assert csp =~ "object-src 'none'"
      assert csp =~ "media-src 'none'"
    end
  end

  describe "init/1" do
    test "returns options unchanged" do
      assert SecurityHeadersPlug.init([]) == []
      assert SecurityHeadersPlug.init(foo: :bar) == [foo: :bar]
    end
  end
end
