defmodule AgentsApi.RouterTest do
  use AgentsApi.ConnCase

  describe "GET /api/health" do
    test "returns 200 with status ok", %{conn: conn} do
      conn = get(conn, "/api/health")
      assert json_response(conn, 200) == %{"status" => "ok"}
    end

    test "includes security headers", %{conn: conn} do
      conn = get(conn, "/api/health")

      assert get_resp_header(conn, "x-content-type-options") == ["nosniff"]
      assert get_resp_header(conn, "x-frame-options") == ["DENY"]
      assert get_resp_header(conn, "content-security-policy") == ["default-src 'none'"]
    end
  end

  describe "authenticated endpoints without token" do
    test "GET /api/agents returns 401", %{conn: conn} do
      conn = get(conn, "/api/agents")
      assert json_response(conn, 401) == %{"error" => "Invalid or revoked API key"}
    end
  end
end
