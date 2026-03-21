defmodule Agents.Infrastructure.Mcp.Tools.Pr.ReviewTool do
  @moduledoc "Submit a review event for an internal pull request."

  use Hermes.Server.Component, type: :tool

  alias Agents.Infrastructure.Mcp.PermissionGuard
  alias Agents.Infrastructure.Mcp.Tools.Pr.Helpers
  alias Agents.Pipeline
  alias Hermes.Server.Response

  schema do
    field(:number, {:required, :integer}, description: "Pull request number")
    field(:event, {:required, :string}, description: "approve | request_changes | comment")
    field(:body, :string, description: "Review summary")
  end

  @impl true
  def execute(params, frame) do
    number = Helpers.get_param(params, :number)

    case PermissionGuard.check_permission(frame, "pr.review") do
      :ok ->
        attrs = %{
          actor_id: Helpers.actor_id(frame),
          event: Helpers.get_param(params, :event),
          body: Helpers.get_param(params, :body)
        }

        case Pipeline.review_pull_request(number, attrs) do
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
