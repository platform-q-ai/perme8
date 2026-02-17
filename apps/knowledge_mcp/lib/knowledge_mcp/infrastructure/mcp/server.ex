defmodule KnowledgeMcp.Infrastructure.Mcp.Server do
  @moduledoc """
  Hermes MCP server definition for the Knowledge MCP service.

  Registers all 6 knowledge tool components and configures the server
  with name "knowledge-mcp" and version "1.0.0".
  """

  use Hermes.Server,
    name: "knowledge-mcp",
    version: "1.0.0",
    capabilities: [:tools]

  alias KnowledgeMcp.Infrastructure.Mcp.Tools

  component(Tools.SearchTool, name: "knowledge.search")
  component(Tools.GetTool, name: "knowledge.get")
  component(Tools.TraverseTool, name: "knowledge.traverse")
  component(Tools.CreateTool, name: "knowledge.create")
  component(Tools.UpdateTool, name: "knowledge.update")
  component(Tools.RelateTool, name: "knowledge.relate")

  @impl true
  def init(_client_info, frame) do
    {:ok, frame}
  end
end
