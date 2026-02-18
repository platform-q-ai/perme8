defmodule Agents.Application.UseCases.TraverseKnowledgeGraph do
  @moduledoc """
  Traverses the knowledge graph from a starting entry.

  Validates the relationship type, clamps depth, verifies the start entity
  exists, then calls ERM traverse with appropriate filters.

  ## Limitations

  The ERM `traverse/3` does not currently support `edge_type` filtering.
  When a `relationship_type` is provided, it is validated for correctness but
  the actual traversal returns all reachable neighbors regardless of edge type.
  True edge-type-filtered traversal requires an ERM enhancement (see follow-up).
  """

  alias Agents.Application.GatewayConfig
  alias Agents.Domain.Entities.KnowledgeEntry
  alias Agents.Domain.Policies.{KnowledgeValidationPolicy, SearchPolicy}

  @spec execute(String.t(), map(), keyword()) ::
          {:ok, [KnowledgeEntry.t()]} | {:error, atom()}
  def execute(workspace_id, params, opts \\ []) do
    erm_gateway = Keyword.get(opts, :erm_gateway, GatewayConfig.erm_gateway())
    relationship_type = Map.get(params, :relationship_type)
    depth = SearchPolicy.clamp_depth(Map.get(params, :depth))

    with {:ok, start_id} <- fetch_required(params, :start_id),
         :ok <- validate_relationship_type(relationship_type),
         {:ok, _entity} <- erm_gateway.get_entity(workspace_id, start_id) do
      traverse_opts =
        [max_depth: depth]
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

  defp fetch_required(map, key) do
    case Map.fetch(map, key) do
      {:ok, _value} = ok -> ok
      :error -> {:error, :missing_required_param}
    end
  end

  defp maybe_add_edge_type(opts, nil), do: opts
  defp maybe_add_edge_type(opts, edge_type), do: Keyword.put(opts, :edge_type, edge_type)
end
