defmodule AgentsApi.Plugs.ApiPermissionPlugTest do
  use AgentsApi.ConnCase

  alias AgentsApi.Plugs.ApiPermissionPlug
  alias Identity.Domain.Entities.ApiKey

  describe "call/2" do
    test "allows when permissions include required scope", %{conn: conn} do
      conn =
        conn
        |> Plug.Conn.assign(:api_key, api_key_with_permissions(["agents:read"]))
        |> ApiPermissionPlug.call("agents:read")

      refute conn.halted
    end

    test "allows when permissions are nil for backward compatibility", %{conn: conn} do
      conn =
        conn
        |> Plug.Conn.assign(:api_key, api_key_with_permissions(nil))
        |> ApiPermissionPlug.call("agents:read")

      refute conn.halted
    end

    test "allows when permissions include global wildcard", %{conn: conn} do
      conn =
        conn
        |> Plug.Conn.assign(:api_key, api_key_with_permissions(["*"]))
        |> ApiPermissionPlug.call("agents:read")

      refute conn.halted
    end

    test "allows when permissions include category wildcard", %{conn: conn} do
      conn =
        conn
        |> Plug.Conn.assign(:api_key, api_key_with_permissions(["agents:*"]))
        |> ApiPermissionPlug.call("agents:read")

      refute conn.halted
    end

    test "denies when scope is not allowed", %{conn: conn} do
      conn =
        conn
        |> Plug.Conn.assign(:api_key, api_key_with_permissions(["agents:read"]))
        |> ApiPermissionPlug.call("agents:write")

      assert conn.halted
      assert conn.status == 403

      assert Jason.decode!(conn.resp_body) == %{
               "error" => "insufficient_permissions",
               "required" => "agents:write"
             }
    end

    test "denies when permissions are empty", %{conn: conn} do
      conn =
        conn
        |> Plug.Conn.assign(:api_key, api_key_with_permissions([]))
        |> ApiPermissionPlug.call("agents:write")

      assert conn.halted
      assert conn.status == 403

      assert Jason.decode!(conn.resp_body) == %{
               "error" => "insufficient_permissions",
               "required" => "agents:write"
             }
    end

    test "passes through unchanged on success", %{conn: conn} do
      conn =
        conn
        |> Plug.Conn.assign(:api_key, api_key_with_permissions(["agents:read"]))

      result = ApiPermissionPlug.call(conn, "agents:read")

      refute result.halted
      assert result == conn
    end
  end

  describe "init/1" do
    test "returns required scope" do
      assert ApiPermissionPlug.init(scope: "agents:read") == "agents:read"
    end
  end

  defp api_key_with_permissions(permissions) do
    ApiKey.new(%{
      id: Ecto.UUID.generate(),
      name: "Test Key",
      hashed_token: "hashed",
      user_id: Ecto.UUID.generate(),
      workspace_access: [],
      permissions: permissions,
      is_active: true
    })
  end
end
