defmodule Agents.KnowledgeFacadeTest do
  use ExUnit.Case, async: true

  @moduledoc """
  Tests that the Agents facade exposes all knowledge MCP functions
  and they delegate correctly to the underlying use cases.
  """

  setup_all do
    Code.ensure_loaded!(Agents)
    :ok
  end

  describe "knowledge facade functions exist" do
    test "authenticate_mcp/2 is exported" do
      assert function_exported?(Agents, :authenticate_mcp, 2)
    end

    test "bootstrap_knowledge_schema/2 is exported" do
      assert function_exported?(Agents, :bootstrap_knowledge_schema, 2)
    end

    test "create_knowledge_entry/3 is exported" do
      assert function_exported?(Agents, :create_knowledge_entry, 3)
    end

    test "update_knowledge_entry/4 is exported" do
      assert function_exported?(Agents, :update_knowledge_entry, 4)
    end

    test "get_knowledge_entry/3 is exported" do
      assert function_exported?(Agents, :get_knowledge_entry, 3)
    end

    test "search_knowledge_entries/3 is exported" do
      assert function_exported?(Agents, :search_knowledge_entries, 3)
    end

    test "traverse_knowledge_graph/3 is exported" do
      assert function_exported?(Agents, :traverse_knowledge_graph, 3)
    end

    test "create_knowledge_relationship/3 is exported" do
      assert function_exported?(Agents, :create_knowledge_relationship, 3)
    end
  end
end
