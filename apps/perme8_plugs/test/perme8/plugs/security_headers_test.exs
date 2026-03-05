defmodule Perme8.Plugs.SecurityHeadersTest do
  @moduledoc """
  Tests for the shared SecurityHeaders plug that adds standard security
  headers to all responses with profile-specific CSP policies.
  """
  use ExUnit.Case, async: true

  import Plug.Conn
  import Plug.Test

  alias Perme8.Plugs.SecurityHeaders

  describe "init/1" do
    test "accepts :liveview profile" do
      config = SecurityHeaders.init(profile: :liveview)
      assert is_map(config)
      assert Map.has_key?(config, :csp)
    end

    test "accepts :api profile" do
      config = SecurityHeaders.init(profile: :api)
      assert is_map(config)
      assert Map.has_key?(config, :csp)
    end

    test "raises ArgumentError when profile is missing" do
      assert_raise ArgumentError, ~r/missing required :profile option/, fn ->
        SecurityHeaders.init([])
      end
    end

    test "raises ArgumentError for invalid profile" do
      assert_raise ArgumentError, ~r/invalid profile :unknown/, fn ->
        SecurityHeaders.init(profile: :unknown)
      end
    end
  end

  describe "call/2 with :liveview profile" do
    setup do
      config = SecurityHeaders.init(profile: :liveview)
      conn = conn(:get, "/") |> SecurityHeaders.call(config)
      %{conn: conn}
    end

    test "sets x-content-type-options header", %{conn: conn} do
      assert get_resp_header(conn, "x-content-type-options") == ["nosniff"]
    end

    test "sets x-frame-options header", %{conn: conn} do
      assert get_resp_header(conn, "x-frame-options") == ["DENY"]
    end

    test "sets referrer-policy header", %{conn: conn} do
      assert get_resp_header(conn, "referrer-policy") == ["strict-origin-when-cross-origin"]
    end

    test "sets strict-transport-security header", %{conn: conn} do
      assert get_resp_header(conn, "strict-transport-security") == [
               "max-age=31536000; includeSubDomains"
             ]
    end

    test "sets permissions-policy header", %{conn: conn} do
      assert get_resp_header(conn, "permissions-policy") == [
               "camera=(), microphone=(), geolocation=()"
             ]
    end

    test "sets CSP with unsafe-inline for script-src and style-src", %{conn: conn} do
      [csp] = get_resp_header(conn, "content-security-policy")
      assert csp =~ "script-src 'self' 'unsafe-inline'"
      assert csp =~ "style-src 'self' 'unsafe-inline'"
    end

    test "sets comprehensive CSP directives for LiveView", %{conn: conn} do
      [csp] = get_resp_header(conn, "content-security-policy")
      assert csp =~ "default-src 'self'"
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

  describe "call/2 with :api profile" do
    setup do
      config = SecurityHeaders.init(profile: :api)
      conn = conn(:get, "/") |> SecurityHeaders.call(config)
      %{conn: conn}
    end

    test "sets restrictive CSP for JSON APIs", %{conn: conn} do
      assert get_resp_header(conn, "content-security-policy") == ["default-src 'none'"]
    end

    test "sets all six security headers", %{conn: conn} do
      assert get_resp_header(conn, "x-content-type-options") != []
      assert get_resp_header(conn, "x-frame-options") != []
      assert get_resp_header(conn, "referrer-policy") != []
      assert get_resp_header(conn, "content-security-policy") != []
      assert get_resp_header(conn, "strict-transport-security") != []
      assert get_resp_header(conn, "permissions-policy") != []
    end
  end

  describe "shared headers across profiles" do
    test "non-CSP headers are identical for both profiles" do
      liveview_config = SecurityHeaders.init(profile: :liveview)
      api_config = SecurityHeaders.init(profile: :api)

      liveview_conn = conn(:get, "/") |> SecurityHeaders.call(liveview_config)
      api_conn = conn(:get, "/") |> SecurityHeaders.call(api_config)

      for header <- [
            "x-content-type-options",
            "x-frame-options",
            "referrer-policy",
            "strict-transport-security",
            "permissions-policy"
          ] do
        assert get_resp_header(liveview_conn, header) == get_resp_header(api_conn, header),
               "Header #{header} differs between profiles"
      end
    end

    test "CSP differs between profiles" do
      liveview_config = SecurityHeaders.init(profile: :liveview)
      api_config = SecurityHeaders.init(profile: :api)

      liveview_conn = conn(:get, "/") |> SecurityHeaders.call(liveview_config)
      api_conn = conn(:get, "/") |> SecurityHeaders.call(api_config)

      refute get_resp_header(liveview_conn, "content-security-policy") ==
               get_resp_header(api_conn, "content-security-policy")
    end
  end

  describe "Plug behaviour" do
    test "implements Plug behaviour" do
      assert function_exported?(SecurityHeaders, :init, 1)
      assert function_exported?(SecurityHeaders, :call, 2)
    end
  end
end
