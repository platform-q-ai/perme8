defmodule Agents.Infrastructure.Mcp.Tools.Pr.MergeTool do
  @moduledoc "Merge an approved internal pull request."

  use Hermes.Server.Component, type: :tool

  alias Agents.Infrastructure.Mcp.PermissionGuard
  alias Agents.Infrastructure.Mcp.Tools.Pr.Helpers
  alias Agents.Pipeline
  alias Hermes.Server.Response

  schema do
    field(:number, {:required, :integer}, description: "Pull request number")
    field(:merge_method, :string, description: "merge | squash")
  end

  @impl true
  def execute(params, frame) do
    number = Helpers.get_param(params, :number)
    merge_method = Helpers.get_param(params, :merge_method) || "merge"

    git_merger =
      Application.get_env(:agents, :pr_git_merger, Agents.Pipeline.Infrastructure.GitMerger)

    case PermissionGuard.check_permission(frame, "pr.merge") do
      :ok ->
        case Pipeline.merge_pull_request(number,
               merge_method: merge_method,
               git_merger: git_merger
             ) do
          {:ok, pr} ->
            {:reply, Response.text(Response.tool(), Helpers.format_summary(pr)), frame}

          {:error, :not_found} ->
            {:reply, Response.error(Response.tool(), "PR ##{number} not found."), frame}

          {:error, reason} ->
            {:reply, Response.error(Response.tool(), Helpers.format_error(reason, "PR")), frame}
        end

      {:error, scope} ->
        {:reply, Response.error(Response.tool(), "Insufficient permissions: #{scope} required"),
         frame}
    end
  end
end
