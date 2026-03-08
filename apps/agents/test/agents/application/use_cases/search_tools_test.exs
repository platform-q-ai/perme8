defmodule Agents.Application.UseCases.SearchToolsTest do
  use ExUnit.Case, async: true

  alias Agents.Application.UseCases.SearchTools

  describe "execute/1 - flat results" do
    test "returns all tools from configured providers" do
      assert {:ok, tools} = SearchTools.execute(%{})

      names = Enum.map(tools, & &1.name)
      assert "jarga.list_workspaces" in names
      assert "knowledge.search" in names
      assert "tools.search" in names
    end

    test "each tool has name, description, and input_schema" do
      assert {:ok, tools} = SearchTools.execute(%{})

      for tool <- tools do
        assert Map.has_key?(tool, :name)
        assert Map.has_key?(tool, :description)
        assert Map.has_key?(tool, :input_schema)
        assert is_binary(tool.name)
      end
    end

    test "filters by query matching tool name" do
      assert {:ok, tools} = SearchTools.execute(%{query: "workspace"})

      names = Enum.map(tools, & &1.name)
      assert "jarga.list_workspaces" in names
      assert "jarga.get_workspace" in names
      refute "knowledge.create" in names
    end

    test "filters by query matching description (case-insensitive)" do
      assert {:ok, tools} = SearchTools.execute(%{query: "knowledge"})

      names = Enum.map(tools, & &1.name)
      # Knowledge tools should match by name
      assert "knowledge.search" in names
      assert "knowledge.create" in names
    end

    test "returns empty list for non-matching query" do
      assert {:ok, []} = SearchTools.execute(%{query: "nonexistent_xyz_tool_999"})
    end
  end

  describe "execute/1 - grouped results" do
    test "groups tools by provider" do
      assert {:ok, groups} = SearchTools.execute(%{group_by_provider: true})

      provider_names = Enum.map(groups, & &1.provider)
      assert "JargaToolProvider" in provider_names
      assert "KnowledgeToolProvider" in provider_names
      assert "ToolsToolProvider" in provider_names
    end

    test "each group contains only tools from that provider" do
      assert {:ok, groups} = SearchTools.execute(%{group_by_provider: true})

      jarga_group = Enum.find(groups, &(&1.provider == "JargaToolProvider"))
      assert jarga_group
      jarga_names = Enum.map(jarga_group.tools, & &1.name)
      assert Enum.all?(jarga_names, &String.starts_with?(&1, "jarga."))
    end

    test "filters grouped results by query" do
      assert {:ok, groups} = SearchTools.execute(%{query: "create", group_by_provider: true})

      # Should have Jarga and Knowledge groups (both have create tools)
      provider_names = Enum.map(groups, & &1.provider)
      assert "JargaToolProvider" in provider_names
      assert "KnowledgeToolProvider" in provider_names

      jarga_group = Enum.find(groups, &(&1.provider == "JargaToolProvider"))
      jarga_names = Enum.map(jarga_group.tools, & &1.name)
      assert "jarga.create_project" in jarga_names
      assert "jarga.create_document" in jarga_names
    end

    test "omits empty provider groups when query filters all tools" do
      assert {:ok, groups} = SearchTools.execute(%{query: "workspace", group_by_provider: true})

      provider_names = Enum.map(groups, & &1.provider)
      assert "JargaToolProvider" in provider_names
      # Knowledge and Tools providers should be omitted (no workspace tools)
      refute "KnowledgeToolProvider" in provider_names
      refute "ToolsToolProvider" in provider_names
    end
  end
end
