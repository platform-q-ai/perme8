defmodule Agents.Application.UseCases.ListProjects do
  @moduledoc "Lists projects within a workspace for the authenticated user."

  alias Agents.Application.GatewayConfig

  @spec execute(String.t(), String.t(), keyword()) :: {:ok, [map()]} | {:error, term()}
  def execute(user_id, workspace_id, opts \\ []) do
    jarga_gateway = Keyword.get(opts, :jarga_gateway, GatewayConfig.jarga_gateway())
    jarga_gateway.list_projects(user_id, workspace_id)
  end
end
