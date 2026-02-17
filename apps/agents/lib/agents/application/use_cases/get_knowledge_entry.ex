defmodule Agents.Application.UseCases.GetKnowledgeEntry do
  @moduledoc """
  Retrieves a knowledge entry with its relationships.

  Fetches the ERM entity and all inbound/outbound edges, converting
  them to domain types.
  """

  alias Agents.Application.GatewayConfig
  alias Agents.Domain.Entities.{KnowledgeEntry, KnowledgeRelationship}

  @spec execute(String.t(), String.t(), keyword()) ::
          {:ok, %{entry: KnowledgeEntry.t(), relationships: [KnowledgeRelationship.t()]}}
          | {:error, :not_found}
  def execute(workspace_id, entity_id, opts \\ []) do
    erm_gateway = Keyword.get(opts, :erm_gateway, GatewayConfig.erm_gateway())

    with {:ok, entity} <- erm_gateway.get_entity(workspace_id, entity_id),
         {:ok, edges} <- erm_gateway.list_edges(workspace_id, %{entity_id: entity_id}) do
      entry = KnowledgeEntry.from_erm_entity(entity)
      relationships = Enum.map(edges, &KnowledgeRelationship.from_erm_edge/1)

      {:ok, %{entry: entry, relationships: relationships}}
    end
  end
end
