defmodule Agents.Infrastructure.Mcp.Tools.Ticket.UpdateTool do
  @moduledoc "Update a GitHub issue via MCP ticket tools."

  use Hermes.Server.Component, type: :tool

  require Logger

  alias Agents.Infrastructure.Mcp.PermissionGuard
  alias Agents.Infrastructure.Mcp.Tools.Ticket.Helpers
  alias Hermes.Server.Response

  @updatable_fields [:title, :body, :labels, :assignees, :state]

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
        handle_update(number, build_attrs(params), frame)

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

  defp handle_update(number, attrs, frame) do
    case Helpers.github_client().update_issue(number, attrs, Helpers.client_opts()) do
      {:ok, issue} ->
        {:reply, Response.text(Response.tool(), "Updated issue ##{issue.number}: #{issue.title}"),
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
         Response.error(Response.tool(), Helpers.format_error(reason, "Issue ##{number}")), frame}
    end
  end
end
