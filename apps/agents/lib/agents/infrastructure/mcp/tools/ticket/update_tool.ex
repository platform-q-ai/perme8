defmodule Agents.Infrastructure.Mcp.Tools.Ticket.UpdateTool do
  @moduledoc "Update a GitHub issue via MCP ticket tools."

  use Hermes.Server.Component, type: :tool

  require Logger

  alias Agents.Infrastructure.Mcp.PermissionGuard
  alias Agents.Infrastructure.Mcp.Tools.Ticket.Helpers
  alias Hermes.Server.Response

  schema do
    field(:number, {:required, :integer}, description: "Issue number")
    field(:title, :string, description: "New title")
    field(:body, :string, description: "New body")
    field(:labels, {:list, :string}, description: "Replacement labels")
    field(:assignees, {:list, :string}, description: "Replacement assignees")
    field(:state, :string, description: "Issue state")
  end

  @impl true
  def execute(params, frame) do
    number = Helpers.get_param(params, :number)

    case PermissionGuard.check_permission(frame, "ticket.update") do
      :ok ->
        attrs =
          [:title, :body, :labels, :assignees, :state]
          |> Enum.reduce(%{}, fn key, acc ->
            value = Helpers.get_param(params, key)

            if is_nil(value) do
              acc
            else
              Map.put(acc, key, value)
            end
          end)

        case Helpers.github_client().update_issue(number, attrs, Helpers.client_opts()) do
          {:ok, issue} ->
            {:reply,
             Response.text(Response.tool(), "Updated issue ##{issue.number}: #{issue.title}"),
             frame}

          {:error, :not_found} ->
            {:reply,
             Response.error(
               Response.tool(),
               Helpers.format_error(:not_found, "Issue ##{number}")
             ), frame}

          {:error, reason} ->
            Logger.error("ticket.update error: #{inspect(reason)}")

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
