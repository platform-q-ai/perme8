defmodule Identity.Infrastructure.Schemas.ApiKeySchemaTest do
  use Identity.DataCase, async: true

  alias Identity.Domain.Entities.ApiKey
  alias Identity.Infrastructure.Schemas.ApiKeySchema

  describe "schema" do
    test "has permissions field with array string type" do
      assert :permissions in ApiKeySchema.__schema__(:fields)
      assert ApiKeySchema.__schema__(:type, :permissions) == {:array, :string}
    end
  end

  describe "changeset/2" do
    test "casts permissions as nil" do
      changeset = ApiKeySchema.changeset(%ApiKeySchema{}, valid_attrs(%{permissions: nil}))

      assert changeset.valid?
      assert Ecto.Changeset.get_field(changeset, :permissions) == nil
    end

    test "casts permissions as empty list" do
      changeset = ApiKeySchema.changeset(%ApiKeySchema{}, valid_attrs(%{permissions: []}))

      assert changeset.valid?
      assert Ecto.Changeset.get_field(changeset, :permissions) == []
    end

    test "casts permissions as valid scope strings" do
      permissions = ["agents:read", "mcp:knowledge.search"]

      changeset =
        ApiKeySchema.changeset(%ApiKeySchema{}, valid_attrs(%{permissions: permissions}))

      assert changeset.valid?
      assert Ecto.Changeset.get_field(changeset, :permissions) == permissions
    end

    test "validates max 100 permissions" do
      permissions = Enum.map(1..101, &"scope:#{&1}")

      changeset =
        ApiKeySchema.changeset(%ApiKeySchema{}, valid_attrs(%{permissions: permissions}))

      refute changeset.valid?
      assert "should have at most 100 item(s)" in errors_on(changeset).permissions
    end
  end

  describe "to_entity/1" do
    test "includes permissions in mapped entity" do
      now = DateTime.utc_now()

      schema = %ApiKeySchema{
        id: Ecto.UUID.generate(),
        name: "Scoped key",
        description: "desc",
        hashed_token: "hash",
        user_id: Ecto.UUID.generate(),
        workspace_access: ["ws-a"],
        permissions: ["agents:read"],
        is_active: true,
        inserted_at: now,
        updated_at: now
      }

      assert %ApiKey{} = entity = ApiKeySchema.to_entity(schema)
      assert entity.permissions == ["agents:read"]
    end
  end

  defp valid_attrs(overrides) do
    Map.merge(
      %{
        name: "Test API Key",
        description: "description",
        hashed_token: "hashed-token",
        user_id: Ecto.UUID.generate(),
        workspace_access: ["workspace-a"],
        is_active: true
      },
      overrides
    )
  end
end
