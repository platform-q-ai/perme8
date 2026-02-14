defmodule EntityRelationshipManager.Views.TraversalJSON do
  @moduledoc """
  JSON view for traversal operation responses.
  """

  def render("neighbors.json", %{entities: entities, meta: meta}) do
    %{data: Enum.map(entities, &entity_data/1), meta: meta}
  end

  def render("neighbors.json", %{entities: entities}) do
    %{
      data: Enum.map(entities, &entity_data/1),
      meta: %{total: length(entities)}
    }
  end

  def render("paths.json", %{paths: paths}) do
    %{
      data:
        Enum.map(paths, fn path ->
          %{
            nodes: Enum.map(Map.get(path, :nodes, []), &entity_data/1),
            edges: Map.get(path, :edges, [])
          }
        end)
    }
  end

  def render("traverse.json", %{entities: entities, edges: edges, meta: meta}) do
    %{
      data: %{
        nodes: Enum.map(entities, &entity_data/1),
        edges: Enum.map(edges, &edge_data/1)
      },
      meta: meta
    }
  end

  def render("traverse.json", %{entities: entities, meta: meta}) do
    %{
      data: %{
        nodes: Enum.map(entities, &entity_data/1),
        edges: []
      },
      meta: meta
    }
  end

  defp entity_data(entity) do
    %{
      id: entity.id,
      workspace_id: entity.workspace_id,
      type: entity.type,
      properties: entity.properties,
      created_at: entity.created_at,
      updated_at: entity.updated_at,
      deleted_at: entity.deleted_at
    }
  end

  defp edge_data(edge) do
    %{
      id: edge.id,
      type: edge.type,
      source_id: edge.source_id,
      target_id: edge.target_id,
      properties: edge.properties
    }
  end
end
