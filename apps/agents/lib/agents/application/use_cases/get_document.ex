defmodule Agents.Application.UseCases.GetDocument do
  @moduledoc "Retrieves a single document by slug within a workspace."

  alias Agents.Application.GatewayConfig

  @spec execute(String.t(), String.t(), String.t(), keyword()) ::
          {:ok, map()} | {:error, :document_not_found | :forbidden}
  def execute(user_id, workspace_id, slug, opts \\ []) do
    jarga_gateway = Keyword.get(opts, :jarga_gateway, GatewayConfig.jarga_gateway())
    jarga_gateway.get_document(user_id, workspace_id, slug)
  end
end
