defmodule EntityRelationshipManager.Views.SchemaJSON do
  @moduledoc """
  JSON view for schema definition responses.
  """

  def render("show.json", %{schema: schema}) do
    %{data: schema_data(schema)}
  end

  defp schema_data(schema) do
    %{
      id: schema.id,
      workspace_id: schema.workspace_id,
      entity_types: Enum.map(schema.entity_types, &type_data/1),
      edge_types: Enum.map(schema.edge_types, &type_data/1),
      version: schema.version,
      created_at: schema.created_at,
      updated_at: schema.updated_at
    }
  end

  defp type_data(type) do
    %{
      name: type.name,
      properties: Enum.map(type.properties, &property_data/1)
    }
  end

  defp property_data(prop) do
    %{
      name: prop.name,
      type: prop.type,
      required: prop.required,
      constraints: prop.constraints
    }
  end
end
