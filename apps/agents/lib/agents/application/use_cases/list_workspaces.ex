defmodule Agents.Application.UseCases.ListWorkspaces do
  @moduledoc "Lists workspaces accessible to the authenticated user."

  alias Agents.Application.GatewayConfig

  @spec execute(String.t(), keyword()) :: {:ok, [map()]} | {:error, term()}
  def execute(user_id, opts \\ []) do
    jarga_gateway = Keyword.get(opts, :jarga_gateway, GatewayConfig.jarga_gateway())
    jarga_gateway.list_workspaces(user_id)
  end
end
