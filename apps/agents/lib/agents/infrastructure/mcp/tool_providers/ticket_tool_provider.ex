defmodule Agents.Infrastructure.Mcp.ToolProviders.TicketToolProvider do
  @moduledoc "Provides the 8 GitHub ticket MCP tool components."

  @behaviour Agents.Infrastructure.Mcp.ToolProvider

  alias Agents.Infrastructure.Mcp.Tools.Ticket

  @impl true
  def components do
    [
      {Ticket.ReadTool, "ticket.read"},
      {Ticket.ListTool, "ticket.list"},
      {Ticket.CreateTool, "ticket.create"},
      {Ticket.UpdateTool, "ticket.update"},
      {Ticket.CloseTool, "ticket.close"},
      {Ticket.CommentTool, "ticket.comment"},
      {Ticket.AddSubIssueTool, "ticket.add_sub_issue"},
      {Ticket.RemoveSubIssueTool, "ticket.remove_sub_issue"}
    ]
  end
end
