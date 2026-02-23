defmodule Agents.Infrastructure.Mcp.ToolProviders.KnowledgeToolProvider do
  @moduledoc """
  Provides the 6 knowledge graph tool components to the MCP server.

  Tools: search, get, traverse, create, update, relate.
  """

  @behaviour Agents.Infrastructure.Mcp.ToolProvider

  alias Agents.Infrastructure.Mcp.Tools

  @impl true
  def components do
    [
      {Tools.SearchTool, "knowledge.search"},
      {Tools.GetTool, "knowledge.get"},
      {Tools.TraverseTool, "knowledge.traverse"},
      {Tools.CreateTool, "knowledge.create"},
      {Tools.UpdateTool, "knowledge.update"},
      {Tools.RelateTool, "knowledge.relate"}
    ]
  end
end
