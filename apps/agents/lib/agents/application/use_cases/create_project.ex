defmodule Agents.Application.UseCases.CreateProject do
  @moduledoc "Creates a new project within a workspace."

  alias Agents.Application.GatewayConfig

  @spec execute(String.t(), String.t(), map(), keyword()) :: {:ok, map()} | {:error, term()}
  def execute(user_id, workspace_id, attrs, opts \\ []) do
    jarga_gateway = Keyword.get(opts, :jarga_gateway, GatewayConfig.jarga_gateway())
    jarga_gateway.create_project(user_id, workspace_id, attrs)
  end
end
