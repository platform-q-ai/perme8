defmodule Agents.Application.UseCases.GetProject do
  @moduledoc "Retrieves a single project by slug within a workspace."

  alias Agents.Application.GatewayConfig

  @spec execute(String.t(), String.t(), String.t(), keyword()) ::
          {:ok, map()} | {:error, :project_not_found}
  def execute(user_id, workspace_id, slug, opts \\ []) do
    jarga_gateway = Keyword.get(opts, :jarga_gateway, GatewayConfig.jarga_gateway())
    jarga_gateway.get_project(user_id, workspace_id, slug)
  end
end
