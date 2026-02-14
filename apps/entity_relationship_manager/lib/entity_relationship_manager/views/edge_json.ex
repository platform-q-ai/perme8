defmodule EntityRelationshipManager.Views.EdgeJSON do
  @moduledoc """
  JSON view for edge responses.
  """

  def render("show.json", %{edge: edge}) do
    %{data: edge_data(edge)}
  end

  def render("index.json", %{edges: edges, meta: meta}) do
    %{data: Enum.map(edges, &edge_data/1), meta: meta}
  end

  def render("index.json", %{edges: edges}) do
    %{data: Enum.map(edges, &edge_data/1), meta: %{total: length(edges)}}
  end

  def render("bulk.json", %{edges: edges, errors: errors, meta: meta}) do
    %{
      data: Enum.map(edges, &edge_data/1),
      errors: errors,
      meta: meta
    }
  end

  def render("bulk.json", %{edges: edges, errors: errors}) do
    %{
      data: Enum.map(edges, &edge_data/1),
      errors: errors,
      meta: %{total: length(edges)}
    }
  end

  defp edge_data(edge) do
    %{
      id: edge.id,
      workspace_id: edge.workspace_id,
      type: edge.type,
      source_id: edge.source_id,
      target_id: edge.target_id,
      properties: edge.properties,
      created_at: edge.created_at,
      updated_at: edge.updated_at,
      deleted_at: edge.deleted_at
    }
  end
end
