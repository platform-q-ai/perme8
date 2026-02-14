defmodule Identity.Domain.Entities.WorkspaceTest do
  use ExUnit.Case, async: true

  alias Identity.Domain.Entities.Workspace

  describe "new/1" do
    test "creates a Workspace struct with given attributes" do
      attrs = %{
        name: "Test Workspace",
        slug: "test-workspace"
      }

      workspace = Workspace.new(attrs)

      assert workspace.name == "Test Workspace"
      assert workspace.slug == "test-workspace"
    end

    test "defaults is_archived to false" do
      workspace = Workspace.new(%{})

      assert workspace.is_archived == false
    end

    test "sets all fields from attributes" do
      attrs = %{
        id: "ws-123",
        name: "Full Workspace",
        slug: "full-workspace",
        description: "A description",
        color: "#3B82F6",
        is_archived: true,
        inserted_at: ~U[2025-01-01 10:00:00Z],
        updated_at: ~U[2025-01-01 10:00:00Z]
      }

      workspace = Workspace.new(attrs)

      assert workspace.id == "ws-123"
      assert workspace.name == "Full Workspace"
      assert workspace.slug == "full-workspace"
      assert workspace.description == "A description"
      assert workspace.color == "#3B82F6"
      assert workspace.is_archived == true
      assert workspace.inserted_at == ~U[2025-01-01 10:00:00Z]
      assert workspace.updated_at == ~U[2025-01-01 10:00:00Z]
    end
  end

  describe "from_schema/1" do
    test "converts an infrastructure schema to domain entity" do
      schema = %{
        __struct__: SomeSchema,
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

      assert %Workspace{} = entity
      assert entity.id == "test-id"
      assert entity.name == "Test Workspace"
      assert entity.slug == "test-workspace"
      assert entity.description == "Description"
      assert entity.color == "#3B82F6"
      assert entity.is_archived == false
      assert entity.inserted_at == ~U[2025-01-01 10:00:00Z]
      assert entity.updated_at == ~U[2025-01-01 10:00:00Z]
    end
  end

  describe "validate_name/1" do
    test "returns :ok for valid name" do
      assert Workspace.validate_name("Valid Name") == :ok
    end

    test "returns error for empty string" do
      assert Workspace.validate_name("") == {:error, :invalid_name}
    end

    test "returns error for nil" do
      assert Workspace.validate_name(nil) == {:error, :invalid_name}
    end
  end

  describe "archived?/1" do
    test "returns true when workspace is archived" do
      workspace = %Workspace{is_archived: true}

      assert Workspace.archived?(workspace) == true
    end

    test "returns false when workspace is not archived" do
      workspace = %Workspace{is_archived: false}

      assert Workspace.archived?(workspace) == false
    end
  end
end
