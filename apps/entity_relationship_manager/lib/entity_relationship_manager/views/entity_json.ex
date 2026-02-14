defmodule EntityRelationshipManager.Views.EntityJSON do
  @moduledoc """
  JSON view for entity responses.
  """

  def render("show.json", %{entity: entity}) do
    %{data: entity_data(entity)}
  end

  def render("index.json", %{entities: entities, meta: meta}) do
    %{data: Enum.map(entities, &entity_data/1), meta: meta}
  end

  def render("index.json", %{entities: entities}) do
    %{data: Enum.map(entities, &entity_data/1), meta: %{total: length(entities)}}
  end

  def render("delete.json", %{entity: entity, deleted_edge_count: count}) do
    %{
      data: entity_data(entity),
      meta: %{edges_deleted: count}
    }
  end

  def render("bulk_create.json", %{entities: entities, errors: errors, meta: meta}) do
    %{
      data: Enum.map(entities, &entity_data/1),
      errors: errors,
      meta: meta
    }
  end

  def render("bulk.json", %{entities: entities, errors: errors, meta: meta}) do
    %{
      data: Enum.map(entities, &entity_data/1),
      errors: errors,
      meta: meta
    }
  end

  def render("bulk.json", %{entities: entities, errors: errors}) do
    %{
      data: Enum.map(entities, &entity_data/1),
      errors: errors,
      meta: %{total: length(entities)}
    }
  end

  def render("bulk_delete.json", %{deleted_count: count, errors: errors, meta: meta}) do
    %{
      data: %{deleted_count: count},
      errors: errors,
      meta: meta
    }
  end

  def render("bulk_delete.json", %{deleted_count: count, errors: errors}) do
    %{
      data: %{deleted_count: count},
      errors: errors,
      meta: %{deleted: count}
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
