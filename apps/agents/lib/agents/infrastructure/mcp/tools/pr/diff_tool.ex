defmodule Agents.Infrastructure.Mcp.Tools.Pr.DiffTool do
  @moduledoc "Compute git diff for an internal pull request."

  use Hermes.Server.Component, type: :tool

  alias Agents.Infrastructure.Mcp.PermissionGuard
  alias Agents.Infrastructure.Mcp.Tools.Pr.Helpers
  alias Agents.Pipeline
  alias Hermes.Server.Response

  schema do
    field(:number, {:required, :integer}, description: "Pull request number")
  end

  @impl true
  def execute(params, frame) do
    number = Helpers.get_param(params, :number)

    diff_computer =
      Application.get_env(
        :agents,
        :pr_diff_computer,
        Agents.Pipeline.Infrastructure.GitDiffComputer
      )

    case PermissionGuard.check_permission(frame, "pr.diff") do
      :ok ->
        case Pipeline.get_pull_request_diff(number, diff_computer: diff_computer) do
          {:ok, %{diff: diff}} ->
            {:reply, Response.text(Response.tool(), diff), frame}

          {:error, :not_found} ->
            {:reply, Response.error(Response.tool(), "PR ##{number} not found."), frame}

          {:error, reason} ->
            {:reply, Response.error(Response.tool(), Helpers.format_error(reason, "PR diff")),
             frame}
        end

      {:error, scope} ->
        {:reply, Response.error(Response.tool(), "Insufficient permissions: #{scope} required"),
         frame}
    end
  end
end
