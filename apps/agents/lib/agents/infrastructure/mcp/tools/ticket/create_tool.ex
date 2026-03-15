defmodule Agents.Infrastructure.Mcp.Tools.Ticket.CreateTool do
  @moduledoc "Create a ticket via the agents domain layer."

  use Hermes.Server.Component, type: :tool

  require Logger

  alias Agents.Infrastructure.Mcp.PermissionGuard
  alias Agents.Infrastructure.Mcp.Tools.Ticket.Helpers
  alias Agents.Tickets
  alias Hermes.Server.Response

  schema do
    field(:title, {:required, :string}, description: "Ticket title")
    field(:body, :string, description: "Ticket body")
  end

  @impl true
  def execute(params, frame) do
    case PermissionGuard.check_permission(frame, "ticket.create") do
      :ok ->
        title = Helpers.get_param(params, :title)
        body = Helpers.get_param(params, :body)

        # Build the raw text that CreateTicket expects: first line = title, rest = body
        raw_text =
          case body do
            nil -> title
            "" -> title
            b -> "#{title}\n#{b}"
          end

        opts = [actor_id: Helpers.actor_id(frame)]

        case Tickets.create_ticket(raw_text, opts) do
          {:ok, schema} ->
            text = "Created ticket ##{schema.number}: #{schema.title}"
            {:reply, Response.text(Response.tool(), text), frame}

          {:error, :body_required} ->
            {:reply, Response.error(Response.tool(), "Title is required."), frame}

          {:error, reason} ->
            Logger.error("ticket.create error: #{inspect(reason)}")

            {:reply, Response.error(Response.tool(), Helpers.format_error(reason, "Ticket")),
             frame}
        end

      {:error, scope} ->
        {:reply, Response.error(Response.tool(), "Insufficient permissions: #{scope} required"),
         frame}
    end
  end
end
