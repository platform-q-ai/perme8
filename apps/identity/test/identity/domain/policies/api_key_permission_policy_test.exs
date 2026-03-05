defmodule Identity.Domain.Policies.ApiKeyPermissionPolicyTest do
  use ExUnit.Case, async: true

  alias Identity.Domain.Policies.ApiKeyPermissionPolicy

  describe "has_permission?/2" do
    test "returns true when permissions are nil" do
      assert ApiKeyPermissionPolicy.has_permission?(nil, "agents:read")
    end

    test "returns true for any scope when wildcard is present" do
      assert ApiKeyPermissionPolicy.has_permission?(["*"], "agents:read")
      assert ApiKeyPermissionPolicy.has_permission?(["*"], "mcp:knowledge.search")
    end

    test "matches exact scopes" do
      assert ApiKeyPermissionPolicy.has_permission?(["agents:read"], "agents:read")
      refute ApiKeyPermissionPolicy.has_permission?(["agents:read"], "agents:write")
    end

    test "matches category wildcard scopes" do
      assert ApiKeyPermissionPolicy.has_permission?(["agents:*"], "agents:read")
      assert ApiKeyPermissionPolicy.has_permission?(["agents:*"], "agents:write")
      assert ApiKeyPermissionPolicy.has_permission?(["agents:*"], "agents:query")
      refute ApiKeyPermissionPolicy.has_permission?(["agents:*"], "mcp:knowledge.search")
    end

    test "matches nested wildcard scopes" do
      assert ApiKeyPermissionPolicy.has_permission?(["mcp:knowledge.*"], "mcp:knowledge.search")
      assert ApiKeyPermissionPolicy.has_permission?(["mcp:knowledge.*"], "mcp:knowledge.get")

      refute ApiKeyPermissionPolicy.has_permission?(
               ["mcp:knowledge.*"],
               "mcp:jarga.list_workspaces"
             )
    end

    test "matches mcp category wildcard scopes" do
      assert ApiKeyPermissionPolicy.has_permission?(["mcp:*"], "mcp:knowledge.search")
      assert ApiKeyPermissionPolicy.has_permission?(["mcp:*"], "mcp:jarga.list_workspaces")
      refute ApiKeyPermissionPolicy.has_permission?(["mcp:*"], "agents:read")
    end

    test "returns false for empty permissions list" do
      refute ApiKeyPermissionPolicy.has_permission?([], "agents:read")
    end

    test "matches when any scope in a list matches" do
      permissions = ["agents:read", "mcp:knowledge.*"]

      assert ApiKeyPermissionPolicy.has_permission?(permissions, "agents:read")
      assert ApiKeyPermissionPolicy.has_permission?(permissions, "mcp:knowledge.search")
      refute ApiKeyPermissionPolicy.has_permission?(permissions, "agents:write")
    end
  end

  describe "permission_summary/1" do
    test "returns full_access for nil and wildcard permissions" do
      assert ApiKeyPermissionPolicy.permission_summary(nil) == :full_access
      assert ApiKeyPermissionPolicy.permission_summary(["*"]) == :full_access
    end

    test "returns no_access for empty permissions" do
      assert ApiKeyPermissionPolicy.permission_summary([]) == :no_access
    end

    test "returns read_only for read only preset" do
      permissions = ApiKeyPermissionPolicy.presets()["Read Only"]
      assert ApiKeyPermissionPolicy.permission_summary(permissions) == :read_only
    end

    test "returns agent_operator for agent operator preset" do
      permissions = ApiKeyPermissionPolicy.presets()["Agent Operator"]
      assert ApiKeyPermissionPolicy.permission_summary(permissions) == :agent_operator
    end

    test "returns custom tuple for non-preset permissions" do
      permissions = ["agents:read", "mcp:knowledge.search"]
      assert ApiKeyPermissionPolicy.permission_summary(permissions) == {:custom, 2}
    end
  end

  describe "valid_scope?/1" do
    test "accepts valid scopes" do
      assert ApiKeyPermissionPolicy.valid_scope?("*")
      assert ApiKeyPermissionPolicy.valid_scope?("agents:read")
      assert ApiKeyPermissionPolicy.valid_scope?("agents:*")
      assert ApiKeyPermissionPolicy.valid_scope?("mcp:knowledge.*")
    end

    test "rejects invalid scopes" do
      refute ApiKeyPermissionPolicy.valid_scope?("agents")
      refute ApiKeyPermissionPolicy.valid_scope?("agents:read:extra")
      refute ApiKeyPermissionPolicy.valid_scope?("Agents:read")
      refute ApiKeyPermissionPolicy.valid_scope?("agents:read-write")
    end
  end

  describe "presets/0" do
    test "returns required permission presets" do
      assert ApiKeyPermissionPolicy.presets() == %{
               "Full Access" => ["*"],
               "Read Only" => [
                 "agents:read",
                 "mcp:knowledge.search",
                 "mcp:knowledge.get",
                 "mcp:knowledge.traverse",
                 "mcp:jarga.list_workspaces",
                 "mcp:jarga.get_workspace",
                 "mcp:jarga.list_projects",
                 "mcp:jarga.get_project",
                 "mcp:jarga.list_documents",
                 "mcp:jarga.get_document"
               ],
               "Agent Operator" => ["agents:read", "agents:write", "agents:query"]
             }
    end
  end

  describe "all_scopes/0" do
    test "returns canonical REST and MCP scopes" do
      assert ApiKeyPermissionPolicy.all_scopes() == [
               "agents:read",
               "agents:write",
               "agents:query",
               "mcp:knowledge.search",
               "mcp:knowledge.get",
               "mcp:knowledge.traverse",
               "mcp:knowledge.create",
               "mcp:knowledge.update",
               "mcp:knowledge.relate",
               "mcp:jarga.list_workspaces",
               "mcp:jarga.get_workspace",
               "mcp:jarga.list_projects",
               "mcp:jarga.create_project",
               "mcp:jarga.get_project",
               "mcp:jarga.list_documents",
               "mcp:jarga.create_document",
               "mcp:jarga.get_document"
             ]
    end
  end
end
