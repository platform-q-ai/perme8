defmodule Agents.Infrastructure.Mcp.Tools.Ticket.CommentTool do
  @moduledoc "Add a comment to a GitHub issue via MCP ticket tools."

  use Hermes.Server.Component, type: :tool

  require Logger

  alias Agents.Infrastructure.Mcp.PermissionGuard
  alias Agents.Infrastructure.Mcp.Tools.Ticket.Helpers
  alias Hermes.Server.Response

  schema do
    field(:number, {:required, :integer}, description: "Issue number")
    field(:body, {:required, :string}, description: "Comment text")
  end

  @impl true
  def execute(params, frame) do
    number = Helpers.get_param(params, :number)
    body = Helpers.get_param(params, :body)

    case PermissionGuard.check_permission(frame, "ticket.comment") do
      :ok ->
        case Helpers.github_client().add_comment(number, body, Helpers.client_opts()) do
          {:ok, comment} ->
            {:reply,
             Response.text(
               Response.tool(),
               "Comment added to ##{number}: #{comment.url || "(no url)"}"
             ), frame}

          {:error, :not_found} ->
            {:reply,
             Response.error(
               Response.tool(),
               Helpers.format_error(:not_found, "Issue ##{number}")
             ), frame}

          {:error, reason} ->
            Logger.error("ticket.comment error: #{inspect(reason)}")

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
