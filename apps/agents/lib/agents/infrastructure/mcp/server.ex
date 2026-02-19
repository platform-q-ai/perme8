defmodule Agents.Infrastructure.Mcp.Server do
  @moduledoc """
  Hermes MCP server definition for the Agents MCP service.

  Registers 14 tool components (6 knowledge + 8 jarga) and configures
  the server with name "knowledge-mcp" and version "1.0.0".
  """

  use Hermes.Server,
    name: "knowledge-mcp",
    version: "1.0.0",
    capabilities: [:tools]

  alias Agents.Infrastructure.Mcp.Tools
  alias Agents.Infrastructure.Mcp.Tools.Jarga

  # Knowledge tools (6)
  component(Tools.SearchTool, name: "knowledge.search")
  component(Tools.GetTool, name: "knowledge.get")
  component(Tools.TraverseTool, name: "knowledge.traverse")
  component(Tools.CreateTool, name: "knowledge.create")
  component(Tools.UpdateTool, name: "knowledge.update")
  component(Tools.RelateTool, name: "knowledge.relate")

  # Jarga tools (8)
  component(Jarga.ListWorkspacesTool, name: "jarga.list_workspaces")
  component(Jarga.GetWorkspaceTool, name: "jarga.get_workspace")
  component(Jarga.ListProjectsTool, name: "jarga.list_projects")
  component(Jarga.CreateProjectTool, name: "jarga.create_project")
  component(Jarga.GetProjectTool, name: "jarga.get_project")
  component(Jarga.ListDocumentsTool, name: "jarga.list_documents")
  component(Jarga.CreateDocumentTool, name: "jarga.create_document")
  component(Jarga.GetDocumentTool, name: "jarga.get_document")

  @impl true
  def init(_client_info, frame) do
    {:ok, frame}
  end
end
