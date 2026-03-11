defmodule Agents.Infrastructure.Mcp.Tools.Ticket.ListTool do
  @moduledoc "List GitHub issues with optional filters via MCP ticket tools."

  use Hermes.Server.Component, type: :tool

  require Logger

  alias Agents.Infrastructure.Mcp.PermissionGuard
  alias Agents.Infrastructure.Mcp.Tools.Ticket.Helpers
  alias Hermes.Server.Response

  schema do
    field(:state, :string, description: "Issue state filter (open/closed/all)")
    field(:labels, {:list, :string}, description: "Label filters")
    field(:assignee, :string, description: "Assignee login")
    field(:query, :string, description: "Search query")
    field(:per_page, :integer, description: "Maximum issues to return")
  end

  @impl true
  def execute(params, frame) do
    case PermissionGuard.check_permission(frame, "ticket.list") do
      :ok ->
        opts =
          (Helpers.client_opts() ++
             [
               state: Helpers.get_param(params, :state),
               labels: Helpers.get_param(params, :labels),
               assignee: Helpers.get_param(params, :assignee),
               query: Helpers.get_param(params, :query),
               per_page: Helpers.get_param(params, :per_page)
             ])
          |> Enum.reject(fn {_key, value} -> is_nil(value) end)

        case Helpers.github_client().list_issues(opts) do
          {:ok, []} ->
            {:reply, Response.text(Response.tool(), "No issues found."), frame}

          {:ok, issues} ->
            text = Enum.map_join(issues, "\n", &Helpers.format_issue_summary/1)
            {:reply, Response.text(Response.tool(), text), frame}

          {:error, reason} ->
            Logger.error("ticket.list error: #{inspect(reason)}")

            {:reply, Response.error(Response.tool(), Helpers.format_error(reason, "Issue list")),
             frame}
        end

      {:error, scope} ->
        {:reply, Response.error(Response.tool(), "Insufficient permissions: #{scope} required"),
         frame}
    end
  end
end
