defmodule Perme8DashboardWeb.EndpointTest do
  use Perme8DashboardWeb.ConnCase, async: true

  describe "endpoint" do
    test "module exists and is a Phoenix.Endpoint" do
      assert {:module, Perme8DashboardWeb.Endpoint} =
               Code.ensure_loaded(Perme8DashboardWeb.Endpoint)

      assert function_exported?(Perme8DashboardWeb.Endpoint, :url, 0)
      assert function_exported?(Perme8DashboardWeb.Endpoint, :config, 1)
    end

    test "health check returns 200", %{conn: conn} do
      conn = get(conn, "/health")
      assert response(conn, 200)
    end
  end
end
