defmodule Agents.Infrastructure.Mcp.SecurityHeadersPlugTest do
  @moduledoc """
  Tests for the SecurityHeadersPlug that adds standard security
  headers to all MCP API responses.
  """
  use ExUnit.Case, async: true

  import Plug.Conn
  import Plug.Test

  alias Agents.Infrastructure.Mcp.SecurityHeadersPlug

  describe "call/2" do
    test "sets x-content-type-options header" do
      conn = build_conn() |> SecurityHeadersPlug.call([])
      assert get_resp_header(conn, "x-content-type-options") == ["nosniff"]
    end

    test "sets x-frame-options header" do
      conn = build_conn() |> SecurityHeadersPlug.call([])
      assert get_resp_header(conn, "x-frame-options") == ["DENY"]
    end

    test "sets referrer-policy header" do
      conn = build_conn() |> SecurityHeadersPlug.call([])
      assert get_resp_header(conn, "referrer-policy") == ["strict-origin-when-cross-origin"]
    end

    test "sets content-security-policy header" do
      conn = build_conn() |> SecurityHeadersPlug.call([])
      assert get_resp_header(conn, "content-security-policy") == ["default-src 'none'"]
    end

    test "sets strict-transport-security header" do
      conn = build_conn() |> SecurityHeadersPlug.call([])

      assert get_resp_header(conn, "strict-transport-security") == [
               "max-age=31536000; includeSubDomains"
             ]
    end

    test "sets permissions-policy header" do
      conn = build_conn() |> SecurityHeadersPlug.call([])

      assert get_resp_header(conn, "permissions-policy") == [
               "camera=(), microphone=(), geolocation=()"
             ]
    end

    test "sets all six security headers in a single call" do
      conn = build_conn() |> SecurityHeadersPlug.call([])

      assert get_resp_header(conn, "x-content-type-options") != []
      assert get_resp_header(conn, "x-frame-options") != []
      assert get_resp_header(conn, "referrer-policy") != []
      assert get_resp_header(conn, "content-security-policy") != []
      assert get_resp_header(conn, "strict-transport-security") != []
      assert get_resp_header(conn, "permissions-policy") != []
    end
  end

  describe "init/1" do
    test "passes options through unchanged" do
      assert SecurityHeadersPlug.init([]) == []
      assert SecurityHeadersPlug.init(foo: :bar) == [foo: :bar]
    end
  end

  defp build_conn do
    conn(:get, "/health")
  end
end
