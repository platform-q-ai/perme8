defmodule Agents.Infrastructure.Mcp.ToolProvider.LoaderTest do
  use ExUnit.Case, async: true

  alias Agents.Infrastructure.Mcp.ToolProvider.Loader

  describe "module definition" do
    test "Loader module exists" do
      assert Code.ensure_loaded?(Loader)
    end

    test "defines __using__/1 macro" do
      macros = Loader.__info__(:macros)

      assert {:__using__, 1} in macros
    end
  end

  describe "compile-time tool loading via Server" do
    # The Loader reads :agents, :mcp_tool_providers at compile time via
    # Application.compile_env/3 and emits component() calls.
    # We test this indirectly through the Server module which uses the Loader.

    test "Server.__components__(:tool) returns all 14 tools from configured providers" do
      components = Agents.Infrastructure.Mcp.Server.__components__(:tool)

      assert length(components) == 14
    end

    test "Server includes all knowledge tools loaded by KnowledgeToolProvider" do
      names =
        Agents.Infrastructure.Mcp.Server.__components__(:tool)
        |> Enum.map(& &1.name)

      knowledge_names = [
        "knowledge.search",
        "knowledge.get",
        "knowledge.traverse",
        "knowledge.create",
        "knowledge.update",
        "knowledge.relate"
      ]

      for name <- knowledge_names do
        assert name in names, "expected #{name} in #{inspect(names)}"
      end
    end

    test "Server includes all jarga tools loaded by JargaToolProvider" do
      names =
        Agents.Infrastructure.Mcp.Server.__components__(:tool)
        |> Enum.map(& &1.name)

      jarga_names = [
        "jarga.list_workspaces",
        "jarga.get_workspace",
        "jarga.list_projects",
        "jarga.create_project",
        "jarga.get_project",
        "jarga.list_documents",
        "jarga.create_document",
        "jarga.get_document"
      ]

      for name <- jarga_names do
        assert name in names, "expected #{name} in #{inspect(names)}"
      end
    end
  end
end
