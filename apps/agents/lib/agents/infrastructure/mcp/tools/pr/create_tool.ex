defmodule Agents.Infrastructure.Mcp.Tools.Pr.CreateTool do
  @moduledoc "Create an internal pull request artifact."

  use Hermes.Server.Component, type: :tool

  alias Agents.Infrastructure.Mcp.PermissionGuard
  alias Agents.Infrastructure.Mcp.Tools.Pr.Helpers
  alias Agents.Pipeline
  alias Hermes.Server.Response

  schema do
    field(:source_branch, {:required, :string}, description: "Source branch")
    field(:target_branch, {:required, :string}, description: "Target branch")
    field(:title, {:required, :string}, description: "Pull request title")
    field(:body, :string, description: "Pull request description")
    field(:linked_ticket, :integer, description: "Linked ticket number")
    field(:status, :string, description: "Initial status")
  end

  @impl true
  def execute(params, frame) do
    case PermissionGuard.check_permission(frame, "pr.create") do
      :ok ->
        attrs =
          %{
            source_branch: Helpers.get_param(params, :source_branch),
            target_branch: Helpers.get_param(params, :target_branch),
            title: Helpers.get_param(params, :title),
            body: Helpers.get_param(params, :body),
            linked_ticket: Helpers.get_param(params, :linked_ticket),
            status: Helpers.get_param(params, :status)
          }
          |> Enum.reject(fn {_k, v} -> is_nil(v) end)
          |> Map.new()

        case Pipeline.create_pull_request(attrs) do
          {:ok, pr} ->
            {:reply, Response.text(Response.tool(), Helpers.format_summary(pr)), frame}

          {:error, reason} ->
            {:reply, Response.error(Response.tool(), Helpers.format_error(reason, "PR")), frame}
        end

      {:error, scope} ->
        {:reply, Response.error(Response.tool(), "Insufficient permissions: #{scope} required"),
         frame}
    end
  end
end
