defmodule Agents.Infrastructure.Mcp.ToolProviders.ToolsToolProviderTest do
  use ExUnit.Case, async: true

  alias Agents.Infrastructure.Mcp.ToolProviders.ToolsToolProvider

  describe "components/0" do
    test "returns exactly 1 component spec" do
      components = ToolsToolProvider.components()

      assert length(components) == 1
    end

    test "each spec is a {module, name} tuple" do
      for {mod, name} <- ToolsToolProvider.components() do
        assert is_atom(mod), "expected module to be an atom, got: #{inspect(mod)}"
        assert is_binary(name), "expected name to be a string, got: #{inspect(name)}"
      end
    end

    test "includes tools.search tool name" do
      names = Enum.map(ToolsToolProvider.components(), fn {_mod, name} -> name end)

      assert "tools.search" in names
    end

    test "all referenced modules are valid Hermes components" do
      for {mod, _name} <- ToolsToolProvider.components() do
        assert Code.ensure_loaded?(mod), "expected #{inspect(mod)} to be loaded"

        assert function_exported?(mod, :__mcp_component_type__, 0),
               "expected #{inspect(mod)} to be a Hermes.Server.Component"
      end
    end
  end
end
