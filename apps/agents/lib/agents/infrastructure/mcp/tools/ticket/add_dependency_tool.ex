defmodule Agents.Infrastructure.Mcp.Tools.Ticket.AddDependencyTool do
  @moduledoc "Add a blocking dependency between two tickets."

  use Hermes.Server.Component, type: :tool

  require Logger

  alias Agents.Infrastructure.Mcp.PermissionGuard
  alias Agents.Infrastructure.Mcp.Tools.Ticket.Helpers
  alias Agents.Tickets
  alias Hermes.Server.Response

  schema do
    field(:blocker_number, {:required, :integer},
      description: "Ticket number that blocks another"
    )

    field(:blocked_number, {:required, :integer}, description: "Ticket number that is blocked")
  end

  @impl true
  def execute(params, frame) do
    blocker_number = Helpers.get_param(params, :blocker_number)
    blocked_number = Helpers.get_param(params, :blocked_number)

    case PermissionGuard.check_permission(frame, "ticket.add_dependency") do
      :ok ->
        opts = [actor_id: Helpers.actor_id(frame)]

        case Tickets.add_dependency_by_number(blocker_number, blocked_number, opts) do
          {:ok, _dep} ->
            {:reply,
             Response.text(
               Response.tool(),
               "Added dependency: ticket ##{blocker_number} blocks ##{blocked_number}."
             ), frame}

          {:error, :ticket_not_found} ->
            {:reply, Response.error(Response.tool(), "One or both tickets not found."), frame}

          {:error, :self_dependency} ->
            {:reply, Response.error(Response.tool(), "A ticket cannot depend on itself."), frame}

          {:error, :duplicate_dependency} ->
            {:reply, Response.error(Response.tool(), "This dependency already exists."), frame}

          {:error, :circular_dependency} ->
            {:reply,
             Response.error(
               Response.tool(),
               "Cannot add dependency — it would create a circular chain."
             ), frame}

          {:error, reason} ->
            Logger.error("ticket.add_dependency error: #{inspect(reason)}")

            {:reply, Response.error(Response.tool(), Helpers.format_error(reason, "Dependency")),
             frame}
        end

      {:error, scope} ->
        {:reply, Response.error(Response.tool(), "Insufficient permissions: #{scope} required"),
         frame}
    end
  end
end
