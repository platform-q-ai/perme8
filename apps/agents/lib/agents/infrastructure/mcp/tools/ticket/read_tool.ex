defmodule Agents.Infrastructure.Mcp.Tools.Ticket.ReadTool do
  @moduledoc "Read a ticket by number from the agents DB."

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

    case PermissionGuard.check_permission(frame, "ticket.read") do
      :ok ->
        case Tickets.get_ticket_by_number(number) do
          {:ok, ticket} ->
            {:reply, Response.text(Response.tool(), Helpers.format_ticket(ticket)), frame}

          {:error, :ticket_not_found} ->
            {:reply,
             Response.error(
               Response.tool(),
               Helpers.format_error(:ticket_not_found, "Ticket ##{number}")
             ), frame}

          {:error, reason} ->
            Logger.error("ticket.read error: #{inspect(reason)}")

            {:reply,
             Response.error(
               Response.tool(),
               Helpers.format_error(reason, "Ticket ##{number}")
             ), frame}
        end

      {:error, scope} ->
        {:reply, Response.error(Response.tool(), "Insufficient permissions: #{scope} required"),
         frame}
    end
  end
end
