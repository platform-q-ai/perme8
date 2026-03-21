defmodule Agents.Infrastructure.Mcp.ToolProviders.PrToolProvider do
  @moduledoc "Provides internal pull request MCP tools."

  @behaviour Agents.Infrastructure.Mcp.ToolProvider

  alias Agents.Infrastructure.Mcp.Tools.Pr

  @impl true
  def components do
    [
      {Pr.CreateTool, "pr.create"},
      {Pr.ReadTool, "pr.read"},
      {Pr.UpdateTool, "pr.update"},
      {Pr.ListTool, "pr.list"},
      {Pr.DiffTool, "pr.diff"},
      {Pr.CommentTool, "pr.comment"},
      {Pr.ReviewTool, "pr.review"},
      {Pr.MergeTool, "pr.merge"},
      {Pr.CloseTool, "pr.close"}
    ]
  end
end
