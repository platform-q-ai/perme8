defmodule Identity.Infrastructure.Schemas.WorkspaceSchemaTest do
  use Identity.DataCase, async: true

  alias Identity.Infrastructure.Schemas.WorkspaceSchema
  alias Identity.Domain.Entities.Workspace

  describe "changeset/2" do
    test "validates required fields" do
      changeset = WorkspaceSchema.changeset(%WorkspaceSchema{}, %{})
      refute changeset.valid?
      assert %{name: ["can't be blank"], slug: ["can't be blank"]} = errors_on(changeset)
    end

    test "validates name minimum length" do
      changeset = WorkspaceSchema.changeset(%WorkspaceSchema{}, %{name: "", slug: "test"})
      refute changeset.valid?
      assert %{name: [_]} = errors_on(changeset)
    end

    test "valid changeset with required fields" do
      changeset =
        WorkspaceSchema.changeset(%WorkspaceSchema{}, %{
          name: "My Workspace",
          slug: "my-workspace"
        })

      assert changeset.valid?
    end

    test "enforces slug uniqueness constraint" do
      # Insert a workspace first
      {:ok, _} =
        %WorkspaceSchema{}
        |> WorkspaceSchema.changeset(%{name: "First", slug: "unique-slug"})
        |> Repo.insert()

      # Try to insert another with the same slug
      {:error, changeset} =
        %WorkspaceSchema{}
        |> WorkspaceSchema.changeset(%{name: "Second", slug: "unique-slug"})
        |> Repo.insert()

      assert %{slug: ["has already been taken"]} = errors_on(changeset)
    end

    test "accepts domain entity and converts to schema for changeset" do
      workspace = %Workspace{
        id: Ecto.UUID.generate(),
        name: "Test Workspace",
        slug: "test-workspace"
      }

      changeset = WorkspaceSchema.changeset(workspace, %{name: "Updated Name"})
      assert changeset.valid?
    end
  end

  describe "to_schema/1" do
    test "converts domain entity to schema struct" do
      workspace = %Workspace{
        id: "test-id",
        name: "Test Workspace",
        slug: "test-workspace",
        description: "A test workspace",
        color: "#4A90E2",
        is_archived: false,
        inserted_at: ~U[2025-01-01 00:00:00Z],
        updated_at: ~U[2025-01-01 00:00:00Z]
      }

      schema = WorkspaceSchema.to_schema(workspace)

      assert %WorkspaceSchema{} = schema
      assert schema.id == "test-id"
      assert schema.name == "Test Workspace"
      assert schema.slug == "test-workspace"
      assert schema.description == "A test workspace"
      assert schema.color == "#4A90E2"
      assert schema.is_archived == false
    end

    test "returns schema unchanged if already a schema" do
      schema = %WorkspaceSchema{
        id: "test-id",
        name: "Test Workspace",
        slug: "test-workspace"
      }

      assert ^schema = WorkspaceSchema.to_schema(schema)
    end
  end
end
