defmodule Agents.Infrastructure.Mcp.Tools.Ticket.CreateTool do
  @moduledoc "Create a GitHub issue via MCP ticket tools."

  use Hermes.Server.Component, type: :tool

  require Logger

  alias Agents.Infrastructure.Mcp.PermissionGuard
  alias Agents.Infrastructure.Mcp.Tools.Ticket.Helpers
  alias Hermes.Server.Response

  schema do
    field(:title, {:required, :string}, description: "Issue title")
    field(:body, :string, description: "Issue body")
    field(:labels, {:list, :string}, description: "Label names")
    field(:assignees, {:list, :string}, description: "Assignee usernames")
  end

  @impl true
  def execute(params, frame) do
    case PermissionGuard.check_permission(frame, "ticket.create") do
      :ok ->
        attrs = %{
          title: Helpers.get_param(params, :title),
          body: Helpers.get_param(params, :body),
          labels: Helpers.get_param(params, :labels),
          assignees: Helpers.get_param(params, :assignees)
        }

        case Helpers.github_client().create_issue(attrs, Helpers.client_opts()) do
          {:ok, issue} ->
            text = "Created issue ##{issue.number}: #{issue.title}\n#{issue.url}"
            {:reply, Response.text(Response.tool(), text), frame}

          {:error, reason} ->
            Logger.error("ticket.create error: #{inspect(reason)}")

            {:reply, Response.error(Response.tool(), Helpers.format_error(reason, "Issue")),
             frame}
        end

      {:error, scope} ->
        {:reply, Response.error(Response.tool(), "Insufficient permissions: #{scope} required"),
         frame}
    end
  end
end
