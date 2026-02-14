defmodule EntityRelationshipManager.Views.EntityJSON do
  @moduledoc """
  JSON view for entity responses.
  """

  def render("show.json", %{entity: entity}) do
    %{data: entity_data(entity)}
  end

  def render("index.json", %{entities: entities}) do
    %{data: Enum.map(entities, &entity_data/1)}
  end

  def render("delete.json", %{entity: entity, deleted_edge_count: count}) do
    %{
      data: entity_data(entity),
      meta: %{deleted_edge_count: count}
    }
  end

  def render("bulk.json", %{entities: entities, errors: errors}) do
    %{
      data: Enum.map(entities, &entity_data/1),
      errors: errors
    }
  end

  def render("bulk_delete.json", %{deleted_count: count, errors: errors}) do
    %{
      data: %{deleted_count: count},
      errors: errors
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
end
