defmodule EntityRelationshipManager.Views.TraversalJSON do
  @moduledoc """
  JSON view for traversal operation responses.
  """

  def render("neighbors.json", %{entities: entities}) do
    %{data: Enum.map(entities, &entity_data/1)}
  end

  def render("paths.json", %{paths: paths}) do
    %{data: paths}
  end

  def render("traverse.json", %{entities: entities}) do
    %{data: Enum.map(entities, &entity_data/1)}
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
end
