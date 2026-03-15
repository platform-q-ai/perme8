defmodule Agents.Infrastructure.Mcp.Tools.Ticket.UpdateTool do
  @moduledoc "Update a ticket's fields via the agents domain layer."

  use Hermes.Server.Component, type: :tool

  require Logger

  alias Agents.Infrastructure.Mcp.PermissionGuard
  alias Agents.Infrastructure.Mcp.Tools.Ticket.Helpers
  alias Agents.Tickets
  alias Hermes.Server.Response

  @updatable_fields [:title, :body, :labels, :assignees, :state]

  schema do
    field(:number, {:required, :integer}, description: "Ticket number")
    field(:title, :string, description: "New title")
    field(:body, :string, description: "New body")
    field(:labels, {:list, :string}, description: "Replacement labels")
    field(:assignees, {:list, :string}, description: "Replacement assignees")
    field(:state, :string, description: "Ticket state")
  end

  @impl true
  def execute(params, frame) do
    number = Helpers.get_param(params, :number)

    case PermissionGuard.check_permission(frame, "ticket.update") do
      :ok ->
        attrs = build_attrs(params)
        opts = [actor_id: Helpers.actor_id(frame)]

        case Tickets.update_ticket(number, attrs, opts) do
          {:ok, schema} ->
            {:reply,
             Response.text(Response.tool(), "Updated ticket ##{schema.number}: #{schema.title}"),
             frame}

          {:error, :not_found} ->
            {:reply,
             Response.error(
               Response.tool(),
               Helpers.format_error(:not_found, "Ticket ##{number}")
             ), frame}

          {:error, :no_changes} ->
            {:reply, Response.error(Response.tool(), Helpers.format_error(:no_changes, nil)),
             frame}

          {:error, reason} ->
            Logger.error("ticket.update error: #{inspect(reason)}")

            {:reply,
             Response.error(Response.tool(), Helpers.format_error(reason, "Ticket ##{number}")),
             frame}
        end

      {:error, scope} ->
        {:reply, Response.error(Response.tool(), "Insufficient permissions: #{scope} required"),
         frame}
    end
  end

  defp build_attrs(params) do
    for key <- @updatable_fields,
        value = Helpers.get_param(params, key),
        not is_nil(value),
        into: %{},
        do: {key, value}
  end
end
