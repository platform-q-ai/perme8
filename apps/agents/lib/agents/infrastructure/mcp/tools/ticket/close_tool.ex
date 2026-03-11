defmodule Agents.Infrastructure.Mcp.Tools.Ticket.CloseTool do
  @moduledoc "Close a GitHub issue with an optional comment via MCP ticket tools."

  use Hermes.Server.Component, type: :tool

  require Logger

  alias Agents.Infrastructure.Mcp.PermissionGuard
  alias Agents.Infrastructure.Mcp.Tools.Ticket.Helpers
  alias Hermes.Server.Response

  schema do
    field(:number, {:required, :integer}, description: "Issue number")
    field(:comment, :string, description: "Optional closing comment")
  end

  @impl true
  def execute(params, frame) do
    number = Helpers.get_param(params, :number)
    comment = Helpers.get_param(params, :comment)

    case PermissionGuard.check_permission(frame, "ticket.close") do
      :ok ->
        opts = [comment: comment] ++ Helpers.client_opts()

        case Helpers.github_client().close_issue_with_comment(number, opts) do
          {:ok, issue} ->
            {:reply,
             Response.text(
               Response.tool(),
               "Closed issue ##{issue.number} (state: #{issue.state})."
             ), frame}

          {:error, :not_found} ->
            {:reply,
             Response.error(
               Response.tool(),
               Helpers.format_error(:not_found, "Issue ##{number}")
             ), frame}

          {:error, reason} ->
            Logger.error("ticket.close error: #{inspect(reason)}")

            {:reply,
             Response.error(Response.tool(), Helpers.format_error(reason, "Issue ##{number}")),
             frame}
        end

      {:error, scope} ->
        {:reply, Response.error(Response.tool(), "Insufficient permissions: #{scope} required"),
         frame}
    end
  end
end
