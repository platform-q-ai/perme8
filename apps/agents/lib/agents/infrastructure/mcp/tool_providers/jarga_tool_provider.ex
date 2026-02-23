defmodule Agents.Infrastructure.Mcp.ToolProviders.JargaToolProvider do
  @moduledoc """
  Provides the 8 Jarga project management tool components to the MCP server.

  Tools: list_workspaces, get_workspace, list_projects, create_project,
  get_project, list_documents, create_document, get_document.
  """

  @behaviour Agents.Infrastructure.Mcp.ToolProvider

  alias Agents.Infrastructure.Mcp.Tools.Jarga

  @impl true
  def components do
    [
      {Jarga.ListWorkspacesTool, "jarga.list_workspaces"},
      {Jarga.GetWorkspaceTool, "jarga.get_workspace"},
      {Jarga.ListProjectsTool, "jarga.list_projects"},
      {Jarga.CreateProjectTool, "jarga.create_project"},
      {Jarga.GetProjectTool, "jarga.get_project"},
      {Jarga.ListDocumentsTool, "jarga.list_documents"},
      {Jarga.CreateDocumentTool, "jarga.create_document"},
      {Jarga.GetDocumentTool, "jarga.get_document"}
    ]
  end
end
