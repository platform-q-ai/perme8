defmodule Jarga.Accounts.Domain.Policies.WorkspaceAccessPolicyTest do
  use ExUnit.Case, async: true

  alias Jarga.Accounts.Domain.Policies.WorkspaceAccessPolicy
  alias Jarga.Accounts.Domain.Entities.ApiKey

  describe "valid_workspace_access?/1" do
    test "accepts empty list" do
      assert WorkspaceAccessPolicy.valid_workspace_access?([]) == :ok
    end

    test "accepts valid workspace slugs" do
      assert WorkspaceAccessPolicy.valid_workspace_access?(["workspace1", "workspace2"]) == :ok
    end

    test "rejects duplicate workspace slugs" do
      assert WorkspaceAccessPolicy.valid_workspace_access?(["workspace1", "workspace1"]) == :error
    end

    test "rejects nil workspace slugs" do
      assert WorkspaceAccessPolicy.valid_workspace_access?(["workspace1", nil]) == :error
    end
  end

  describe "has_workspace_access?/2" do
    test "returns true for workspace in list" do
      api_key =
        ApiKey.new(%{
          id: "key-1",
          name: "Test Key",
          hashed_token: "hashed",
          user_id: "user-1",
          workspace_access: ["workspace1", "workspace2"],
          is_active: true
        })

      assert WorkspaceAccessPolicy.has_workspace_access?(api_key, "workspace1") == true
    end

    test "returns false for workspace not in list" do
      api_key =
        ApiKey.new(%{
          id: "key-1",
          name: "Test Key",
          hashed_token: "hashed",
          user_id: "user-1",
          workspace_access: ["workspace1", "workspace2"],
          is_active: true
        })

      assert WorkspaceAccessPolicy.has_workspace_access?(api_key, "workspace3") == false
    end

    test "returns false when workspace_access is empty" do
      api_key =
        ApiKey.new(%{
          id: "key-1",
          name: "Test Key",
          hashed_token: "hashed",
          user_id: "user-1",
          workspace_access: [],
          is_active: true
        })

      assert WorkspaceAccessPolicy.has_workspace_access?(api_key, "workspace1") == false
    end

    test "returns false when workspace_access is nil" do
      api_key =
        ApiKey.new(%{
          id: "key-1",
          name: "Test Key",
          hashed_token: "hashed",
          user_id: "user-1",
          workspace_access: nil,
          is_active: true
        })

      assert WorkspaceAccessPolicy.has_workspace_access?(api_key, "workspace1") == false
    end
  end

  describe "list_accessible_workspaces/2" do
    test "filters workspaces by API key's workspace_access" do
      api_key =
        ApiKey.new(%{
          id: "key-1",
          name: "Test Key",
          hashed_token: "hashed",
          user_id: "user-1",
          workspace_access: ["product-team", "engineering"],
          is_active: true
        })

      all_workspaces = [
        %{id: "w1", name: "Product Team", slug: "product-team"},
        %{id: "w2", name: "Engineering", slug: "engineering"},
        %{id: "w3", name: "Marketing", slug: "marketing"}
      ]

      result = WorkspaceAccessPolicy.list_accessible_workspaces(api_key, all_workspaces)

      assert length(result) == 2
      assert Enum.any?(result, fn w -> w.slug == "product-team" end)
      assert Enum.any?(result, fn w -> w.slug == "engineering" end)
      refute Enum.any?(result, fn w -> w.slug == "marketing" end)
    end

    test "returns empty list when API key has no workspace access" do
      api_key =
        ApiKey.new(%{
          id: "key-1",
          name: "Test Key",
          hashed_token: "hashed",
          user_id: "user-1",
          workspace_access: [],
          is_active: true
        })

      all_workspaces = [
        %{id: "w1", name: "Product Team", slug: "product-team"},
        %{id: "w2", name: "Engineering", slug: "engineering"}
      ]

      result = WorkspaceAccessPolicy.list_accessible_workspaces(api_key, all_workspaces)

      assert result == []
    end

    test "returns empty list when workspace_access is nil" do
      api_key =
        ApiKey.new(%{
          id: "key-1",
          name: "Test Key",
          hashed_token: "hashed",
          user_id: "user-1",
          workspace_access: nil,
          is_active: true
        })

      all_workspaces = [
        %{id: "w1", name: "Product Team", slug: "product-team"}
      ]

      result = WorkspaceAccessPolicy.list_accessible_workspaces(api_key, all_workspaces)

      assert result == []
    end

    test "returns empty list when all_workspaces is empty" do
      api_key =
        ApiKey.new(%{
          id: "key-1",
          name: "Test Key",
          hashed_token: "hashed",
          user_id: "user-1",
          workspace_access: ["product-team"],
          is_active: true
        })

      result = WorkspaceAccessPolicy.list_accessible_workspaces(api_key, [])

      assert result == []
    end

    test "works with domain workspace entities" do
      api_key =
        ApiKey.new(%{
          id: "key-1",
          name: "Test Key",
          hashed_token: "hashed",
          user_id: "user-1",
          workspace_access: ["my-workspace"],
          is_active: true
        })

      # Use the actual Workspace domain entity structure
      all_workspaces = [
        %Jarga.Workspaces.Domain.Entities.Workspace{
          id: "w1",
          name: "My Workspace",
          slug: "my-workspace",
          is_archived: false
        },
        %Jarga.Workspaces.Domain.Entities.Workspace{
          id: "w2",
          name: "Other Workspace",
          slug: "other-workspace",
          is_archived: false
        }
      ]

      result = WorkspaceAccessPolicy.list_accessible_workspaces(api_key, all_workspaces)

      assert length(result) == 1
      assert hd(result).slug == "my-workspace"
    end
  end
end
