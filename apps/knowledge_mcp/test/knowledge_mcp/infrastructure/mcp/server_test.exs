defmodule KnowledgeMcp.Infrastructure.Mcp.ServerTest do
  use ExUnit.Case, async: true

  alias KnowledgeMcp.Infrastructure.Mcp.Server

  describe "server module" do
    test "defines init/2 callback" do
      assert function_exported?(Server, :init, 2)
    end

    test "registers all 6 tool components" do
      components = Server.__components__(:tool)

      assert length(components) == 6
    end

    test "registers knowledge.search tool" do
      tools = Server.__components__(:tool)
      names = Enum.map(tools, & &1.name)

      assert "knowledge.search" in names
    end

    test "registers knowledge.get tool" do
      tools = Server.__components__(:tool)
      names = Enum.map(tools, & &1.name)

      assert "knowledge.get" in names
    end

    test "registers knowledge.traverse tool" do
      tools = Server.__components__(:tool)
      names = Enum.map(tools, & &1.name)

      assert "knowledge.traverse" in names
    end

    test "registers knowledge.create tool" do
      tools = Server.__components__(:tool)
      names = Enum.map(tools, & &1.name)

      assert "knowledge.create" in names
    end

    test "registers knowledge.update tool" do
      tools = Server.__components__(:tool)
      names = Enum.map(tools, & &1.name)

      assert "knowledge.update" in names
    end

    test "registers knowledge.relate tool" do
      tools = Server.__components__(:tool)
      names = Enum.map(tools, & &1.name)

      assert "knowledge.relate" in names
    end

    test "server name is knowledge-mcp" do
      info = Server.server_info()
      assert info["name"] == "knowledge-mcp"
    end

    test "server version is 1.0.0" do
      info = Server.server_info()
      assert info["version"] == "1.0.0"
    end
  end
end
