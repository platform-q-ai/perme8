defmodule Agents.Infrastructure.Mcp.Tools.Pr.ReadTool do
  @moduledoc "Read an internal pull request by number."

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

    case PermissionGuard.check_permission(frame, "pr.read") do
      :ok ->
        case Pipeline.get_pull_request(number) do
          {:ok, pr} ->
            {:reply, Response.text(Response.tool(), Helpers.format_pull_request(pr)), frame}

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
