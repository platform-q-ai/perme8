defmodule Agents.Infrastructure.Mcp.Tools.Pr.UpdateTool do
  @moduledoc "Update internal pull request metadata/state."

  use Hermes.Server.Component, type: :tool

  alias Agents.Infrastructure.Mcp.PermissionGuard
  alias Agents.Infrastructure.Mcp.Tools.Pr.Helpers
  alias Agents.Pipeline
  alias Hermes.Server.Response

  schema do
    field(:number, {:required, :integer}, description: "Pull request number")
    field(:title, :string, description: "Updated title")
    field(:body, :string, description: "Updated body")
    field(:status, :string, description: "Updated status")
    field(:linked_ticket, :integer, description: "Linked ticket")
  end

  @impl true
  def execute(params, frame) do
    number = Helpers.get_param(params, :number)

    case PermissionGuard.check_permission(frame, "pr.update") do
      :ok ->
        attrs =
          %{
            title: Helpers.get_param(params, :title),
            body: Helpers.get_param(params, :body),
            status: Helpers.get_param(params, :status),
            linked_ticket: Helpers.get_param(params, :linked_ticket)
          }
          |> Enum.reject(fn {_k, v} -> is_nil(v) end)
          |> Map.new()

        case Pipeline.update_pull_request(number, attrs) do
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
