defmodule Agents.Infrastructure.Mcp.Tools.Ticket.RemoveSubIssueTool do
  @moduledoc "Unlink a child ticket from a parent ticket via the agents domain layer."

  use Hermes.Server.Component, type: :tool

  require Logger

  alias Agents.Infrastructure.Mcp.PermissionGuard
  alias Agents.Infrastructure.Mcp.Tools.Ticket.Helpers
  alias Agents.Tickets
  alias Hermes.Server.Response

  schema do
    field(:parent_number, {:required, :integer}, description: "Parent ticket number")
    field(:child_number, {:required, :integer}, description: "Child ticket number")
  end

  @impl true
  def execute(params, frame) do
    parent_number = Helpers.get_param(params, :parent_number)
    child_number = Helpers.get_param(params, :child_number)

    case PermissionGuard.check_permission(frame, "ticket.remove_sub_issue") do
      :ok ->
        opts = [actor_id: Helpers.actor_id(frame)]

        case Tickets.remove_sub_issue(parent_number, child_number, opts) do
          {:ok, _schema} ->
            {:reply,
             Response.text(
               Response.tool(),
               "Removed sub-issue ##{child_number} from parent ticket ##{parent_number}."
             ), frame}

          {:error, :not_found} ->
            {:reply,
             Response.error(
               Response.tool(),
               Helpers.format_error(:child_not_found, nil)
             ), frame}

          {:error, reason} ->
            Logger.error("ticket.remove_sub_issue error: #{inspect(reason)}")

            {:reply,
             Response.error(Response.tool(), Helpers.format_error(reason, "Sub-issue unlink")),
             frame}
        end

      {:error, scope} ->
        {:reply, Response.error(Response.tool(), "Insufficient permissions: #{scope} required"),
         frame}
    end
  end
end
