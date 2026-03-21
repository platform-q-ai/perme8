defmodule Agents.Infrastructure.Mcp.Tools.Pr.ListTool do
  @moduledoc "List internal pull requests with optional filters."

  use Hermes.Server.Component, type: :tool

  alias Agents.Infrastructure.Mcp.PermissionGuard
  alias Agents.Infrastructure.Mcp.Tools.Pr.Helpers
  alias Agents.Pipeline
  alias Hermes.Server.Response

  schema do
    field(:state, :string, description: "PR status filter")
    field(:query, :string, description: "Title search")
    field(:per_page, :integer, description: "Maximum rows")
  end

  @impl true
  def execute(params, frame) do
    case PermissionGuard.check_permission(frame, "pr.list") do
      :ok ->
        filters =
          [
            state: Helpers.get_param(params, :state),
            query: Helpers.get_param(params, :query),
            per_page: Helpers.get_param(params, :per_page)
          ]
          |> Enum.reject(fn {_k, v} -> is_nil(v) end)

        case Pipeline.list_pull_requests(filters) do
          {:ok, []} ->
            {:reply, Response.text(Response.tool(), "No pull requests found."), frame}

          {:ok, prs} ->
            text = Enum.map_join(prs, "\n", &Helpers.format_summary/1)
            {:reply, Response.text(Response.tool(), text), frame}
        end

      {:error, scope} ->
        {:reply, Response.error(Response.tool(), "Insufficient permissions: #{scope} required"),
         frame}
    end
  end
end
