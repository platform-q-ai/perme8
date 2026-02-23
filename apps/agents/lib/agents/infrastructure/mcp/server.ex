defmodule Agents.Infrastructure.Mcp.Server do
  @moduledoc """
  Hermes MCP server definition for the Agents MCP service.

  Tool components are registered at compile time from configured ToolProviders.
  See `:agents, :mcp_tool_providers` in application config.
  """

  use Hermes.Server,
    name: "perme8-mcp",
    version: "1.0.0",
    capabilities: [:tools]

  use Agents.Infrastructure.Mcp.ToolProvider.Loader

  @impl true
  def init(_client_info, frame) do
    {:ok, frame}
  end
end
