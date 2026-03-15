defmodule Agents.Infrastructure.Mcp.Tools.Ticket.ListTool do
  @moduledoc "List tickets from the agents DB with optional filters."

  use Hermes.Server.Component, type: :tool

  alias Agents.Infrastructure.Mcp.PermissionGuard
  alias Agents.Infrastructure.Mcp.Tools.Ticket.Helpers
  alias Agents.Tickets
  alias Hermes.Server.Response

  schema do
    field(:state, :string, description: "Issue state filter (open/closed)")
    field(:labels, {:list, :string}, description: "Label filters")
    field(:query, :string, description: "Search query (title or number)")
    field(:per_page, :integer, description: "Maximum tickets to return")
  end

  @impl true
  def execute(params, frame) do
    case PermissionGuard.check_permission(frame, "ticket.list") do
      :ok ->
        opts =
          [
            state: Helpers.get_param(params, :state),
            labels: Helpers.get_param(params, :labels),
            query: Helpers.get_param(params, :query),
            per_page: Helpers.get_param(params, :per_page)
          ]
          |> Enum.reject(fn {_key, value} -> is_nil(value) end)

        case Tickets.list_tickets(opts) do
          [] ->
            {:reply, Response.text(Response.tool(), "No tickets found."), frame}

          tickets ->
            text = Enum.map_join(tickets, "\n", &Helpers.format_ticket_summary/1)
            {:reply, Response.text(Response.tool(), text), frame}
        end

      {:error, scope} ->
        {:reply, Response.error(Response.tool(), "Insufficient permissions: #{scope} required"),
         frame}
    end
  end
end
