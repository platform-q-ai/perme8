defmodule Agents.Infrastructure.Mcp.Tools.Ticket.CloseTool do
  @moduledoc "Close a ticket via the agents domain layer."

  use Hermes.Server.Component, type: :tool

  require Logger

  alias Agents.Infrastructure.Mcp.PermissionGuard
  alias Agents.Infrastructure.Mcp.Tools.Ticket.Helpers
  alias Agents.Tickets
  alias Hermes.Server.Response

  schema do
    field(:number, {:required, :integer}, description: "Ticket number")
  end

  @impl true
  def execute(params, frame) do
    number = Helpers.get_param(params, :number)

    case PermissionGuard.check_permission(frame, "ticket.close") do
      :ok ->
        case Tickets.close_project_ticket(number, []) do
          :ok ->
            {:reply, Response.text(Response.tool(), "Closed ticket ##{number}."), frame}

          {:error, :not_found} ->
            {:reply,
             Response.error(
               Response.tool(),
               Helpers.format_error(:not_found, "Ticket ##{number}")
             ), frame}

          {:error, reason} ->
            Logger.error("ticket.close error: #{inspect(reason)}")

            {:reply,
             Response.error(Response.tool(), Helpers.format_error(reason, "Ticket ##{number}")),
             frame}
        end

      {:error, scope} ->
        {:reply, Response.error(Response.tool(), "Insufficient permissions: #{scope} required"),
         frame}
    end
  end
end
