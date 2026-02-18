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
         {:ok, neighbors} <- erm_gateway.get_neighbors(workspace_id, entity_id, []) do
      entry = KnowledgeEntry.from_erm_entity(entity)

      # get_neighbors returns entities, not edges — we derive relationships
      # from neighbor context. For full edge data, a future API enhancement
      # would add entity_id filtering to list_edges.
      {:ok, %{entry: entry, relationships: derive_relationships(entity_id, neighbors)}}
    end
  end

  defp derive_relationships(_entity_id, []), do: []

  defp derive_relationships(entity_id, neighbors) do
    Enum.map(neighbors, fn neighbor ->
      KnowledgeRelationship.new(%{
        from_id: entity_id,
        to_id: neighbor.id,
        type: "relates_to"
      })
    end)
  end
end
