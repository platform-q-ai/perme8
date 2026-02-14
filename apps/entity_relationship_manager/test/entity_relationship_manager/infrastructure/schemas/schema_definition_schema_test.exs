defmodule EntityRelationshipManager.Infrastructure.Schemas.SchemaDefinitionSchemaTest do
  use EntityRelationshipManager.DataCase, async: true

  alias EntityRelationshipManager.Infrastructure.Schemas.SchemaDefinitionSchema
  alias EntityRelationshipManager.Domain.Entities.SchemaDefinition
  alias EntityRelationshipManager.Domain.Entities.EntityTypeDefinition
  alias EntityRelationshipManager.Domain.Entities.EdgeTypeDefinition

  @valid_attrs %{
    workspace_id: Ecto.UUID.generate(),
    entity_types: [
      %{
        "name" => "Person",
        "properties" => [%{"name" => "name", "type" => "string", "required" => true}]
      }
    ],
    edge_types: [
      %{
        "name" => "KNOWS",
        "properties" => [%{"name" => "since", "type" => "integer", "required" => false}]
      }
    ]
  }

  describe "create_changeset/2" do
    test "valid changeset with all required fields" do
      changeset = SchemaDefinitionSchema.create_changeset(%SchemaDefinitionSchema{}, @valid_attrs)
      assert changeset.valid?
    end

    test "rejects missing workspace_id" do
      attrs = Map.delete(@valid_attrs, :workspace_id)
      changeset = SchemaDefinitionSchema.create_changeset(%SchemaDefinitionSchema{}, attrs)
      refute changeset.valid?
      assert %{workspace_id: ["can't be blank"]} = errors_on(changeset)
    end

    test "rejects nil entity_types" do
      attrs = %{@valid_attrs | entity_types: nil}
      changeset = SchemaDefinitionSchema.create_changeset(%SchemaDefinitionSchema{}, attrs)
      refute changeset.valid?
      assert %{entity_types: ["can't be blank"]} = errors_on(changeset)
    end

    test "rejects nil edge_types" do
      attrs = %{@valid_attrs | edge_types: nil}
      changeset = SchemaDefinitionSchema.create_changeset(%SchemaDefinitionSchema{}, attrs)
      refute changeset.valid?
      assert %{edge_types: ["can't be blank"]} = errors_on(changeset)
    end

    test "accepts empty lists for entity_types and edge_types" do
      attrs = %{@valid_attrs | entity_types: [], edge_types: []}
      changeset = SchemaDefinitionSchema.create_changeset(%SchemaDefinitionSchema{}, attrs)
      assert changeset.valid?
    end
  end

  describe "update_changeset/2" do
    test "valid changeset for updating entity_types and edge_types" do
      existing = %SchemaDefinitionSchema{
        id: Ecto.UUID.generate(),
        workspace_id: Ecto.UUID.generate(),
        entity_types: [],
        edge_types: [],
        version: 1
      }

      update_attrs = %{
        entity_types: [%{"name" => "Company", "properties" => []}],
        edge_types: [%{"name" => "WORKS_AT", "properties" => []}],
        version: 1
      }

      changeset = SchemaDefinitionSchema.update_changeset(existing, update_attrs)
      assert changeset.valid?
    end

    test "rejects missing entity_types on update" do
      existing = %SchemaDefinitionSchema{
        entity_types: [],
        edge_types: [],
        version: 1
      }

      changeset =
        SchemaDefinitionSchema.update_changeset(existing, %{entity_types: nil, edge_types: []})

      refute changeset.valid?
      assert %{entity_types: ["can't be blank"]} = errors_on(changeset)
    end

    test "applies optimistic lock on version" do
      existing = %SchemaDefinitionSchema{
        entity_types: [],
        edge_types: [],
        version: 1
      }

      changeset =
        SchemaDefinitionSchema.update_changeset(existing, %{
          entity_types: [%{"name" => "X", "properties" => []}],
          edge_types: [],
          version: 1
        })

      assert changeset.valid?
      # optimistic_lock adds a filter on the version and an increment function
      # The version field will be incremented by Ecto when the update executes
      assert changeset.filters[:version] == 1
    end
  end

  describe "to_entity/1" do
    test "converts schema to domain SchemaDefinition" do
      now = DateTime.utc_now() |> DateTime.truncate(:second)

      schema = %SchemaDefinitionSchema{
        id: Ecto.UUID.generate(),
        workspace_id: Ecto.UUID.generate(),
        entity_types: [
          %{
            "name" => "Person",
            "properties" => [%{"name" => "name", "type" => "string", "required" => true}]
          }
        ],
        edge_types: [
          %{
            "name" => "KNOWS",
            "properties" => [%{"name" => "since", "type" => "integer", "required" => false}]
          }
        ],
        version: 2,
        inserted_at: now,
        updated_at: now
      }

      result = SchemaDefinitionSchema.to_entity(schema)

      assert %SchemaDefinition{} = result
      assert result.id == schema.id
      assert result.workspace_id == schema.workspace_id
      assert result.version == 2
      assert result.created_at == now
      assert result.updated_at == now

      # Verify entity_types are deserialized
      assert length(result.entity_types) == 1
      assert %EntityTypeDefinition{name: "Person"} = hd(result.entity_types)

      # Verify edge_types are deserialized
      assert length(result.edge_types) == 1
      assert %EdgeTypeDefinition{name: "KNOWS"} = hd(result.edge_types)
    end

    test "handles empty entity_types and edge_types" do
      schema = %SchemaDefinitionSchema{
        id: Ecto.UUID.generate(),
        workspace_id: Ecto.UUID.generate(),
        entity_types: [],
        edge_types: [],
        version: 1,
        inserted_at: DateTime.utc_now() |> DateTime.truncate(:second),
        updated_at: DateTime.utc_now() |> DateTime.truncate(:second)
      }

      result = SchemaDefinitionSchema.to_entity(schema)

      assert result.entity_types == []
      assert result.edge_types == []
    end
  end

  # Helper to extract errors from changeset
  defp errors_on(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {message, opts} ->
      Regex.replace(~r"%{(\w+)}", message, fn _, key ->
        opts |> Keyword.get(String.to_existing_atom(key), key) |> to_string()
      end)
    end)
  end
end
