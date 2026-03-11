defmodule Agents.Infrastructure.Mcp.Tools.Ticket.ReadTool do
  @moduledoc "Read a GitHub issue by number via the MCP ticket tools."

  use Hermes.Server.Component, type: :tool

  require Logger

  alias Agents.Infrastructure.Mcp.PermissionGuard
  alias Agents.Infrastructure.Mcp.Tools.Ticket.Helpers
  alias Hermes.Server.Response

  schema do
    field(:number, {:required, :integer}, description: "Issue number")
  end

  @impl true
  def execute(params, frame) do
    number = Helpers.get_param(params, :number)

    case PermissionGuard.check_permission(frame, "ticket.read") do
      :ok ->
        case Helpers.github_client().get_issue(number, Helpers.client_opts()) do
          {:ok, issue} ->
            {:reply, Response.text(Response.tool(), Helpers.format_issue(issue)), frame}

          {:error, :not_found} ->
            {:reply,
             Response.error(
               Response.tool(),
               Helpers.format_error(:not_found, "Issue ##{number}")
             ), frame}

          {:error, reason} ->
            Logger.error("ticket.read error: #{inspect(reason)}")

            {:reply,
             Response.error(
               Response.tool(),
               Helpers.format_error(reason, "Issue ##{number}")
             ), frame}
        end

      {:error, scope} ->
        {:reply, Response.error(Response.tool(), "Insufficient permissions: #{scope} required"),
         frame}
    end
  end
end
