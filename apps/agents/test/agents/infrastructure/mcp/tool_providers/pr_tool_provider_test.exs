defmodule Agents.Infrastructure.Mcp.ToolProviders.PrToolProviderTest do
  use ExUnit.Case, async: true

  alias Agents.Infrastructure.Mcp.ToolProviders.PrToolProvider

  @expected_names [
    "pr.create",
    "pr.read",
    "pr.update",
    "pr.list",
    "pr.diff",
    "pr.comment",
    "pr.review",
    "pr.merge",
    "pr.close"
  ]

  describe "components/0" do
    test "returns exactly 9 component specs" do
      assert length(PrToolProvider.components()) == 9
    end

    test "includes all pr tool names" do
      names = Enum.map(PrToolProvider.components(), fn {_mod, name} -> name end)

      for expected <- @expected_names do
        assert expected in names
      end
    end
  end
end
