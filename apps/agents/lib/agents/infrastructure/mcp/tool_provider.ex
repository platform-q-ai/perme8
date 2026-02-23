defmodule Agents.Infrastructure.Mcp.ToolProvider do
  @moduledoc """
  Behaviour for modules that provide tool components to the MCP server.

  Implementors return a list of `{module, name}` tuples where each module
  is a `Hermes.Server.Component` and the name is the tool's MCP-visible name.

  ## Example

      defmodule MyProvider do
        @behaviour Agents.Infrastructure.Mcp.ToolProvider

        @impl true
        def components do
          [{MyTool, "my.tool"}]
        end
      end
  """

  @type component_spec :: {module(), String.t()}

  @callback components() :: [component_spec()]
end
