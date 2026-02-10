defmodule Jarga.Accounts.Domain.ApiKeyScopeTest do
  @moduledoc """
  Unit tests for the ApiKeyScope domain module.

  These are pure tests with no database access, testing how Jarga
  interprets API key access scopes in the context of workspaces.
  """

  use ExUnit.Case, async: true

  alias Jarga.Accounts.Domain.ApiKeyScope

  describe "valid?/1" do
    test "returns :ok for empty list" do
      assert ApiKeyScope.valid?([]) == :ok
    end

    test "returns :ok for list with single item" do
      assert ApiKeyScope.valid?(["workspace-1"]) == :ok
    end

    test "returns :ok for list with multiple unique items" do
      scope = ["workspace-1", "workspace-2", "workspace-3"]

      assert ApiKeyScope.valid?(scope) == :ok
    end

    test "returns :error for list with duplicates" do
      scope = ["workspace-1", "workspace-1"]

      assert ApiKeyScope.valid?(scope) == :error
    end

    test "returns :error for list with multiple duplicates" do
      scope = ["ws-a", "ws-b", "ws-a", "ws-c", "ws-b"]

      assert ApiKeyScope.valid?(scope) == :error
    end

    test "returns :error for list containing nil" do
      scope = ["workspace-1", nil]

      assert ApiKeyScope.valid?(scope) == :error
    end

    test "returns :error for list containing only nil" do
      scope = [nil]

      assert ApiKeyScope.valid?(scope) == :error
    end

    test "returns :error for list with nil and duplicates" do
      scope = ["ws-1", nil, "ws-1"]

      assert ApiKeyScope.valid?(scope) == :error
    end
  end

  describe "includes?/2" do
    test "returns true when workspace is in scope" do
      api_key = %{workspace_access: ["product-team", "engineering"]}

      assert ApiKeyScope.includes?(api_key, "product-team") == true
      assert ApiKeyScope.includes?(api_key, "engineering") == true
    end

    test "returns false when workspace is not in scope" do
      api_key = %{workspace_access: ["product-team"]}

      assert ApiKeyScope.includes?(api_key, "marketing") == false
    end

    test "returns false for empty scope" do
      api_key = %{workspace_access: []}

      assert ApiKeyScope.includes?(api_key, "any-workspace") == false
    end

    test "returns false for nil scope" do
      api_key = %{workspace_access: nil}

      assert ApiKeyScope.includes?(api_key, "any-workspace") == false
    end

    test "is case-sensitive" do
      api_key = %{workspace_access: ["Product-Team"]}

      assert ApiKeyScope.includes?(api_key, "Product-Team") == true
      assert ApiKeyScope.includes?(api_key, "product-team") == false
    end
  end

  describe "filter_workspaces/2" do
    test "returns only workspaces within scope" do
      api_key = %{workspace_access: ["product-team"]}

      all_workspaces = [
        %{slug: "product-team", name: "Product"},
        %{slug: "engineering", name: "Engineering"}
      ]

      result = ApiKeyScope.filter_workspaces(api_key, all_workspaces)

      assert length(result) == 1
      assert hd(result).slug == "product-team"
    end

    test "returns multiple workspaces when all are in scope" do
      api_key = %{workspace_access: ["ws-1", "ws-2"]}

      all_workspaces = [
        %{slug: "ws-1", name: "Workspace 1"},
        %{slug: "ws-2", name: "Workspace 2"},
        %{slug: "ws-3", name: "Workspace 3"}
      ]

      result = ApiKeyScope.filter_workspaces(api_key, all_workspaces)

      assert length(result) == 2
      slugs = Enum.map(result, & &1.slug)
      assert "ws-1" in slugs
      assert "ws-2" in slugs
      refute "ws-3" in slugs
    end

    test "returns empty list when no workspaces are in scope" do
      api_key = %{workspace_access: ["non-existent"]}

      all_workspaces = [
        %{slug: "ws-1", name: "Workspace 1"},
        %{slug: "ws-2", name: "Workspace 2"}
      ]

      result = ApiKeyScope.filter_workspaces(api_key, all_workspaces)

      assert result == []
    end

    test "returns empty list for empty scope" do
      api_key = %{workspace_access: []}
      all_workspaces = [%{slug: "ws-1", name: "Workspace 1"}]

      result = ApiKeyScope.filter_workspaces(api_key, all_workspaces)

      assert result == []
    end

    test "returns empty list for nil scope" do
      api_key = %{workspace_access: nil}
      all_workspaces = [%{slug: "ws-1", name: "Workspace 1"}]

      result = ApiKeyScope.filter_workspaces(api_key, all_workspaces)

      assert result == []
    end

    test "returns empty list when all_workspaces is empty" do
      api_key = %{workspace_access: ["ws-1", "ws-2"]}
      all_workspaces = []

      result = ApiKeyScope.filter_workspaces(api_key, all_workspaces)

      assert result == []
    end

    test "preserves workspace structure in results" do
      api_key = %{workspace_access: ["my-ws"]}

      all_workspaces = [
        %{slug: "my-ws", name: "My Workspace", id: "123", extra_field: "value"}
      ]

      result = ApiKeyScope.filter_workspaces(api_key, all_workspaces)

      assert length(result) == 1
      workspace = hd(result)
      assert workspace.slug == "my-ws"
      assert workspace.name == "My Workspace"
      assert workspace.id == "123"
      assert workspace.extra_field == "value"
    end
  end
end
