defmodule Jarga.Workspaces.WorkspaceTest do
  use Jarga.DataCase, async: true

  alias Jarga.Workspaces.Domain.Entities.Workspace

  describe "domain entity" do
    test "new/1 creates a workspace entity" do
      attrs = %{
        name: "Test Workspace",
        slug: "test-workspace"
      }

      workspace = Workspace.new(attrs)

      assert workspace.name == "Test Workspace"
      assert workspace.slug == "test-workspace"
    end

    test "defaults is_archived to false" do
      workspace = %Workspace{}
      assert workspace.is_archived == false
    end

    test "from_schema/1 converts schema to entity" do
      alias Jarga.Workspaces.Infrastructure.Schemas.WorkspaceSchema

      schema = %WorkspaceSchema{
        id: "test-id",
        name: "Test Workspace",
        slug: "test-workspace",
        description: "Description",
        color: "#3B82F6",
        is_archived: false,
        inserted_at: ~U[2025-01-01 10:00:00Z],
        updated_at: ~U[2025-01-01 10:00:00Z]
      }

      entity = Workspace.from_schema(schema)

      assert entity.id == "test-id"
      assert entity.name == "Test Workspace"
      assert entity.slug == "test-workspace"
      assert entity.description == "Description"
      assert entity.color == "#3B82F6"
      assert entity.is_archived == false
    end

    test "validate_name/1 validates business rules" do
      assert Workspace.validate_name("Valid Name") == :ok
      assert Workspace.validate_name("") == {:error, :invalid_name}
      assert Workspace.validate_name(nil) == {:error, :invalid_name}
    end

    test "archived?/1 checks archived status" do
      archived = %Workspace{is_archived: true}
      active = %Workspace{is_archived: false}

      assert Workspace.archived?(archived) == true
      assert Workspace.archived?(active) == false
    end
  end
end
