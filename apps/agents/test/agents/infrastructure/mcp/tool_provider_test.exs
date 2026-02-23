defmodule Agents.Infrastructure.Mcp.ToolProviderTest do
  use ExUnit.Case, async: true

  alias Agents.Infrastructure.Mcp.ToolProvider

  describe "behaviour definition" do
    test "ToolProvider module exists" do
      assert Code.ensure_loaded?(ToolProvider)
    end

    test "defines components/0 callback" do
      callbacks = ToolProvider.behaviour_info(:callbacks)

      assert {:components, 0} in callbacks
    end

    test "a module implementing the behaviour returns expected format" do
      defmodule TestProvider do
        @behaviour Agents.Infrastructure.Mcp.ToolProvider

        @impl true
        def components do
          [{SomeModule, "test.tool"}]
        end
      end

      assert [{SomeModule, "test.tool"}] = TestProvider.components()
    end
  end
end
