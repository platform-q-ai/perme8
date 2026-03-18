defmodule Agents.Infrastructure.Mcp.Tools.Ticket.SearchDependencyTargetsTool do
  @moduledoc "Search for tickets to use as dependency targets (typeahead)."

  use Hermes.Server.Component, type: :tool

  alias Agents.Infrastructure.Mcp.PermissionGuard
  alias Agents.Infrastructure.Mcp.Tools.Ticket.Helpers
  alias Agents.Tickets
  alias Hermes.Server.Response

  schema do
    field(:query, {:required, :string}, description: "Search query (title or number)")

    field(:exclude_ticket_number, {:required, :integer},
      description: "Ticket number to exclude from results"
    )
  end

  @impl true
  def execute(params, frame) do
    query = Helpers.get_param(params, :query)
    exclude_number = Helpers.get_param(params, :exclude_ticket_number)

    case PermissionGuard.check_permission(frame, "ticket.search_dependency_targets") do
      :ok ->
        format_search_results(
          Tickets.search_tickets_for_dependency(query, exclude_number),
          frame
        )

      {:error, scope} ->
        {:reply, Response.error(Response.tool(), "Insufficient permissions: #{scope} required"),
         frame}
    end
  end

  defp format_search_results([], frame) do
    {:reply, Response.text(Response.tool(), "No matching tickets found."), frame}
  end

  defp format_search_results(tickets, frame) do
    text = Enum.map_join(tickets, "\n", fn t -> "Ticket ##{t.number}: #{t.title}" end)
    {:reply, Response.text(Response.tool(), text), frame}
  end
end
