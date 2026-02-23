defmodule Agents.Infrastructure.Mcp.ToolProviders.KnowledgeToolProviderTest do
  use ExUnit.Case, async: true

  alias Agents.Infrastructure.Mcp.ToolProviders.KnowledgeToolProvider

  @expected_names [
    "knowledge.search",
    "knowledge.get",
    "knowledge.traverse",
    "knowledge.create",
    "knowledge.update",
    "knowledge.relate"
  ]

  describe "components/0" do
    test "returns exactly 6 component specs" do
      components = KnowledgeToolProvider.components()

      assert length(components) == 6
    end

    test "each spec is a {module, name} tuple" do
      for {mod, name} <- KnowledgeToolProvider.components() do
        assert is_atom(mod), "expected module to be an atom, got: #{inspect(mod)}"
        assert is_binary(name), "expected name to be a string, got: #{inspect(name)}"
      end
    end

    test "includes all 6 knowledge tool names" do
      names = Enum.map(KnowledgeToolProvider.components(), fn {_mod, name} -> name end)

      for expected <- @expected_names do
        assert expected in names, "expected #{expected} in #{inspect(names)}"
      end
    end

    test "all referenced modules are valid Hermes components" do
      for {mod, _name} <- KnowledgeToolProvider.components() do
        assert Code.ensure_loaded?(mod), "expected #{inspect(mod)} to be loaded"

        assert function_exported?(mod, :__mcp_component_type__, 0),
               "expected #{inspect(mod)} to be a Hermes.Server.Component"
      end
    end
  end
end
