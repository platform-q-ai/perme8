defmodule Agents.Infrastructure.Mcp.ToolProviders.ToolsToolProvider do
  @moduledoc """
  Provides the meta-tool for discovering MCP tools on the perme8-mcp server.

  Tools: tools.search.
  """

  @behaviour Agents.Infrastructure.Mcp.ToolProvider

  alias Agents.Infrastructure.Mcp.Tools.ToolsSearchTool

  @impl true
  def components do
    [{ToolsSearchTool, "tools.search"}]
  end
end
