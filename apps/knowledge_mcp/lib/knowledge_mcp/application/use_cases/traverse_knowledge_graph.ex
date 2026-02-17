defmodule KnowledgeMcp.Application.UseCases.TraverseKnowledgeGraph do
  @moduledoc """
  Traverses the knowledge graph from a starting entry.

  Validates the relationship type, clamps depth, verifies the start entity
  exists, then calls ERM traverse with appropriate filters.
  """

  alias KnowledgeMcp.Domain.Entities.KnowledgeEntry
  alias KnowledgeMcp.Domain.Policies.{KnowledgeValidationPolicy, SearchPolicy}

  @doc """
  Traverses the knowledge graph from a starting entry.

  ## Params

    * `start_id` - ID of the starting entity (required)
    * `relationship_type` - Optional edge type filter
    * `depth` - Optional traversal depth (default 2, max 5)

  ## Options

    * `:erm_gateway` - Module implementing ErmGatewayBehaviour
  """
  @spec execute(String.t(), map(), keyword()) ::
          {:ok, [KnowledgeEntry.t()]} | {:error, atom()}
  def execute(workspace_id, params, opts \\ []) do
    erm_gateway = Keyword.get(opts, :erm_gateway, default_erm_gateway())
    start_id = Map.fetch!(params, :start_id)
    relationship_type = Map.get(params, :relationship_type)
    depth = SearchPolicy.clamp_depth(Map.get(params, :depth))

    with :ok <- validate_relationship_type(relationship_type),
         {:ok, _entity} <- erm_gateway.get_entity(workspace_id, start_id) do
      traverse_opts =
        [depth: depth]
        |> maybe_add_edge_type(relationship_type)

      case erm_gateway.traverse(workspace_id, start_id, traverse_opts) do
        {:ok, entities} ->
          {:ok, Enum.map(entities, &KnowledgeEntry.from_erm_entity/1)}

        {:error, reason} ->
          {:error, reason}
      end
    end
  end

  defp validate_relationship_type(nil), do: :ok

  defp validate_relationship_type(type) do
    if KnowledgeValidationPolicy.valid_relationship_type?(type) do
      :ok
    else
      {:error, :invalid_relationship_type}
    end
  end

  defp maybe_add_edge_type(opts, nil), do: opts
  defp maybe_add_edge_type(opts, edge_type), do: Keyword.put(opts, :edge_type, edge_type)

  defp default_erm_gateway do
    Application.get_env(:knowledge_mcp, :erm_gateway, KnowledgeMcp.Infrastructure.ErmGateway)
  end
end
