defmodule Jarga.Accounts.Infrastructure.Schemas.ApiKeySchemaTest do
  use Jarga.DataCase, async: true

  alias Jarga.Accounts.Infrastructure.Schemas.ApiKeySchema

  describe "changeset/2" do
    test "changeset with valid attributes" do
      attrs = %{
        name: "Test Key",
        hashed_token: "hashed_token_123",
        user_id: Ecto.UUID.generate()
      }

      changeset = ApiKeySchema.changeset(%ApiKeySchema{}, attrs)

      assert changeset.valid?
    end

    test "changeset requires name" do
      attrs = %{
        hashed_token: "hashed_token_123",
        user_id: Ecto.UUID.generate()
      }

      changeset = ApiKeySchema.changeset(%ApiKeySchema{}, attrs)

      refute changeset.valid?
      assert {"can't be blank", _} = Keyword.get(changeset.errors, :name)
    end

    test "changeset requires hashed_token" do
      attrs = %{
        name: "Test Key",
        user_id: Ecto.UUID.generate()
      }

      changeset = ApiKeySchema.changeset(%ApiKeySchema{}, attrs)

      refute changeset.valid?
      assert {"can't be blank", _} = Keyword.get(changeset.errors, :hashed_token)
    end

    test "changeset requires user_id" do
      attrs = %{
        name: "Test Key",
        hashed_token: "hashed_token_123"
      }

      changeset = ApiKeySchema.changeset(%ApiKeySchema{}, attrs)

      refute changeset.valid?
      assert {"can't be blank", _} = Keyword.get(changeset.errors, :user_id)
    end

    test "changeset validates workspace_access format" do
      attrs = %{
        name: "Test Key",
        hashed_token: "hashed_token_123",
        user_id: Ecto.UUID.generate(),
        workspace_access: ["workspace-1", "workspace-2"]
      }

      changeset = ApiKeySchema.changeset(%ApiKeySchema{}, attrs)

      assert changeset.valid?
    end
  end

  describe "to_entity/1" do
    test "converts schema to domain entity" do
      user_id = Ecto.UUID.generate()

      schema = %ApiKeySchema{
        id: Ecto.UUID.generate(),
        name: "Test Key",
        description: "Test description",
        hashed_token: "hashed_token_123",
        user_id: user_id,
        workspace_access: ["workspace-1", "workspace-2"],
        is_active: true,
        inserted_at: DateTime.utc_now(),
        updated_at: DateTime.utc_now()
      }

      entity = ApiKeySchema.to_entity(schema)

      assert entity.id == schema.id
      assert entity.name == schema.name
      assert entity.description == schema.description
      assert entity.hashed_token == schema.hashed_token
      assert entity.user_id == schema.user_id
      assert entity.workspace_access == schema.workspace_access
      assert entity.is_active == schema.is_active
      assert entity.inserted_at == schema.inserted_at
      assert entity.updated_at == schema.updated_at
    end
  end
end
