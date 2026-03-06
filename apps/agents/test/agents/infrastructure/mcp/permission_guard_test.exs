defmodule Agents.Infrastructure.Mcp.PermissionGuardTest do
  use ExUnit.Case, async: true

  import Mox

  alias Agents.Infrastructure.Mcp.PermissionGuard
  alias Agents.Mocks.IdentityMock
  alias Hermes.Server.Frame

  setup :set_mox_from_context
  setup :verify_on_exit!

  describe "check_permission/3" do
    test "returns :ok for nil permissions" do
      api_key = %{id: "key-1", permissions: nil}
      frame = Frame.new(%{api_key: api_key})

      IdentityMock
      |> expect(:api_key_has_permission?, fn ^api_key, "mcp:knowledge.search" -> true end)

      assert :ok =
               PermissionGuard.check_permission(frame, "knowledge.search",
                 identity_module: IdentityMock
               )
    end

    test "returns :ok for wildcard permission list" do
      api_key = %{id: "key-2", permissions: ["*"]}
      frame = Frame.new(%{api_key: api_key})

      IdentityMock
      |> expect(:api_key_has_permission?, fn ^api_key, "mcp:jarga.list_workspaces" -> true end)

      assert :ok =
               PermissionGuard.check_permission(frame, "jarga.list_workspaces",
                 identity_module: IdentityMock
               )
    end

    test "returns :ok for mcp:knowledge.* and error for jarga scope" do
      api_key = %{id: "key-3", permissions: ["mcp:knowledge.*"]}
      frame = Frame.new(%{api_key: api_key})

      IdentityMock
      |> expect(:api_key_has_permission?, fn ^api_key, "mcp:knowledge.search" -> true end)
      |> expect(:api_key_has_permission?, fn ^api_key, "mcp:jarga.list_workspaces" -> false end)

      assert :ok =
               PermissionGuard.check_permission(frame, "knowledge.search",
                 identity_module: IdentityMock
               )

      assert {:error, "mcp:jarga.list_workspaces"} =
               PermissionGuard.check_permission(frame, "jarga.list_workspaces",
                 identity_module: IdentityMock
               )
    end

    test "returns :ok for exact scope and error for others" do
      api_key = %{id: "key-4", permissions: ["mcp:knowledge.search"]}
      frame = Frame.new(%{api_key: api_key})

      IdentityMock
      |> expect(:api_key_has_permission?, fn ^api_key, "mcp:knowledge.search" -> true end)
      |> expect(:api_key_has_permission?, fn ^api_key, "mcp:knowledge.create" -> false end)

      assert :ok =
               PermissionGuard.check_permission(frame, "knowledge.search",
                 identity_module: IdentityMock
               )

      assert {:error, "mcp:knowledge.create"} =
               PermissionGuard.check_permission(frame, "knowledge.create",
                 identity_module: IdentityMock
               )
    end

    test "returns :ok for mcp:* wildcard" do
      api_key = %{id: "key-5", permissions: ["mcp:*"]}
      frame = Frame.new(%{api_key: api_key})

      IdentityMock
      |> expect(:api_key_has_permission?, fn ^api_key, "mcp:knowledge.get" -> true end)

      assert :ok =
               PermissionGuard.check_permission(frame, "knowledge.get",
                 identity_module: IdentityMock
               )
    end

    test "returns required scope when permissions are empty" do
      api_key = %{id: "key-6", permissions: []}
      frame = Frame.new(%{api_key: api_key})

      IdentityMock
      |> expect(:api_key_has_permission?, fn ^api_key, "mcp:knowledge.search" -> false end)

      assert {:error, "mcp:knowledge.search"} =
               PermissionGuard.check_permission(frame, "knowledge.search",
                 identity_module: IdentityMock
               )
    end
  end
end
