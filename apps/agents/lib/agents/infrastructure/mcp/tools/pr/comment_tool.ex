defmodule Agents.Infrastructure.Mcp.Tools.Pr.CommentTool do
  @moduledoc "Add a review comment to an internal pull request."

  use Hermes.Server.Component, type: :tool

  alias Agents.Infrastructure.Mcp.PermissionGuard
  alias Agents.Infrastructure.Mcp.Tools.Pr.Helpers
  alias Agents.Pipeline
  alias Hermes.Server.Response

  schema do
    field(:number, {:required, :integer}, description: "Pull request number")
    field(:body, {:required, :string}, description: "Comment body")
    field(:path, :string, description: "Optional file path")
    field(:line, :integer, description: "Optional line number")
  end

  @impl true
  def execute(params, frame) do
    number = Helpers.get_param(params, :number)

    case PermissionGuard.check_permission(frame, "pr.comment") do
      :ok ->
        attrs = %{
          actor_id: Helpers.actor_id(frame),
          body: Helpers.get_param(params, :body),
          path: Helpers.get_param(params, :path),
          line: Helpers.get_param(params, :line)
        }

        case Pipeline.comment_on_pull_request(number, attrs) do
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
