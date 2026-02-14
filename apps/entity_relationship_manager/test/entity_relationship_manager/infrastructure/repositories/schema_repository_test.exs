defmodule EntityRelationshipManager.Infrastructure.Repositories.SchemaRepositoryTest do
  use EntityRelationshipManager.DataCase, async: true

  @moduletag :database

  alias EntityRelationshipManager.Infrastructure.Repositories.SchemaRepository
  alias EntityRelationshipManager.Infrastructure.Schemas.SchemaDefinitionSchema
  alias EntityRelationshipManager.Domain.Entities.SchemaDefinition

  @entity_types [
    %{
      "name" => "Person",
      "properties" => [%{"name" => "name", "type" => "string", "required" => true}]
    }
  ]
  @edge_types [
    %{
      "name" => "KNOWS",
      "properties" => [%{"name" => "since", "type" => "integer", "required" => false}]
    }
  ]

  defp create_workspace_id, do: Ecto.UUID.generate()

  defp insert_schema!(workspace_id, attrs \\ %{}) do
    default_attrs = %{
      workspace_id: workspace_id,
      entity_types: @entity_types,
      edge_types: @edge_types
    }

    %SchemaDefinitionSchema{}
    |> SchemaDefinitionSchema.create_changeset(Map.merge(default_attrs, attrs))
    |> Jarga.Repo.insert!()
  end

  describe "get_schema/1" do
    test "returns domain entity when schema exists" do
      workspace_id = create_workspace_id()
      insert_schema!(workspace_id)

      assert {:ok, %SchemaDefinition{} = schema} = SchemaRepository.get_schema(workspace_id)
      assert schema.workspace_id == workspace_id
      assert length(schema.entity_types) == 1
      assert length(schema.edge_types) == 1
    end

    test "returns {:error, :not_found} when schema does not exist" do
      workspace_id = create_workspace_id()
      assert {:error, :not_found} = SchemaRepository.get_schema(workspace_id)
    end
  end

  describe "upsert_schema/2" do
    test "creates new schema when none exists" do
      workspace_id = create_workspace_id()

      attrs = %{
        entity_types: @entity_types,
        edge_types: @edge_types
      }

      assert {:ok, %SchemaDefinition{} = schema} =
               SchemaRepository.upsert_schema(workspace_id, attrs)

      assert schema.workspace_id == workspace_id
      assert schema.version == 1
      assert length(schema.entity_types) == 1
      assert length(schema.edge_types) == 1
    end

    test "updates existing schema and increments version" do
      workspace_id = create_workspace_id()
      existing = insert_schema!(workspace_id)

      new_entity_types = [
        %{
          "name" => "Company",
          "properties" => [%{"name" => "name", "type" => "string", "required" => true}]
        }
      ]

      attrs = %{
        entity_types: new_entity_types,
        edge_types: @edge_types,
        version: existing.version
      }

      assert {:ok, %SchemaDefinition{} = updated} =
               SchemaRepository.upsert_schema(workspace_id, attrs)

      assert updated.workspace_id == workspace_id
      assert updated.version == 2
      assert length(updated.entity_types) == 1
      assert hd(updated.entity_types).name == "Company"
    end

    test "rejects stale version on update" do
      workspace_id = create_workspace_id()
      _existing = insert_schema!(workspace_id)

      attrs = %{
        entity_types: @entity_types,
        edge_types: @edge_types,
        version: 999
      }

      assert {:error, :stale} = SchemaRepository.upsert_schema(workspace_id, attrs)
    end
  end
end
