defmodule Agents.Application.UseCases.GetWorkspace do
  @moduledoc "Retrieves a single workspace by slug for the authenticated user."

  alias Agents.Application.GatewayConfig

  @spec execute(String.t(), String.t(), keyword()) ::
          {:ok, map()} | {:error, :not_found | :unauthorized}
  def execute(user_id, workspace_slug, opts \\ []) do
    jarga_gateway = Keyword.get(opts, :jarga_gateway, GatewayConfig.jarga_gateway())
    jarga_gateway.get_workspace(user_id, workspace_slug)
  end
end
