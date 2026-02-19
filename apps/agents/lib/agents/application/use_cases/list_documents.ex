defmodule Agents.Application.UseCases.ListDocuments do
  @moduledoc """
  Lists documents in a workspace, optionally filtered by project.

  When `project_slug` is provided in params, resolves it to a project ID
  via the gateway and filters documents to that project. Otherwise, lists
  all documents in the workspace.
  """

  alias Agents.Application.GatewayConfig

  @spec execute(String.t(), String.t(), map(), keyword()) :: {:ok, [map()]} | {:error, term()}
  def execute(user_id, workspace_id, params, opts \\ []) do
    jarga_gateway = Keyword.get(opts, :jarga_gateway, GatewayConfig.jarga_gateway())

    case Map.get(params, :project_slug) do
      nil ->
        jarga_gateway.list_documents(user_id, workspace_id, [])

      project_slug ->
        with {:ok, project} <- jarga_gateway.get_project(user_id, workspace_id, project_slug) do
          jarga_gateway.list_documents(user_id, workspace_id, project_id: project.id)
        end
    end
  end
end
