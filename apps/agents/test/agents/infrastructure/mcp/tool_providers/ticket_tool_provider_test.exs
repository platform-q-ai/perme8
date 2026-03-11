defmodule Agents.Infrastructure.Mcp.ToolProviders.TicketToolProviderTest do
  use ExUnit.Case, async: true

  alias Agents.Infrastructure.Mcp.ToolProviders.TicketToolProvider

  @expected_names [
    "ticket.read",
    "ticket.list",
    "ticket.create",
    "ticket.update",
    "ticket.close",
    "ticket.comment",
    "ticket.add_sub_issue",
    "ticket.remove_sub_issue"
  ]

  describe "components/0" do
    test "returns exactly 8 component specs" do
      components = TicketToolProvider.components()

      assert length(components) == 8
    end

    test "each spec is a {module, name} tuple" do
      for {mod, name} <- TicketToolProvider.components() do
        assert is_atom(mod), "expected module to be an atom, got: #{inspect(mod)}"
        assert is_binary(name), "expected name to be a string, got: #{inspect(name)}"
      end
    end

    test "includes all 8 ticket tool names" do
      names = Enum.map(TicketToolProvider.components(), fn {_mod, name} -> name end)

      for expected <- @expected_names do
        assert expected in names, "expected #{expected} in #{inspect(names)}"
      end
    end

    test "all referenced modules are valid Hermes components" do
      for {mod, _name} <- TicketToolProvider.components() do
        assert Code.ensure_loaded?(mod), "expected #{inspect(mod)} to be loaded"

        assert function_exported?(mod, :__mcp_component_type__, 0),
               "expected #{inspect(mod)} to be a Hermes.Server.Component"
      end
    end
  end
end
