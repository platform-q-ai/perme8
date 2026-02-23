defmodule Webhooks.Infrastructure.Schemas.InboundWebhookConfigSchemaTest do
  use Webhooks.DataCase, async: true

  alias Webhooks.Infrastructure.Schemas.InboundWebhookConfigSchema

  @valid_attrs %{
    workspace_id: Ecto.UUID.generate(),
    secret: "whsec_inbound_secret_long_enough_for_hmac"
  }

  describe "changeset/2" do
    test "valid changeset with workspace_id and secret" do
      changeset =
        InboundWebhookConfigSchema.changeset(%InboundWebhookConfigSchema{}, @valid_attrs)

      assert changeset.valid?
      assert get_change(changeset, :workspace_id) == @valid_attrs.workspace_id
      assert get_change(changeset, :secret) == @valid_attrs.secret
    end

    test "requires workspace_id" do
      attrs = Map.delete(@valid_attrs, :workspace_id)
      changeset = InboundWebhookConfigSchema.changeset(%InboundWebhookConfigSchema{}, attrs)

      refute changeset.valid?
      assert "can't be blank" in errors_on(changeset).workspace_id
    end

    test "requires secret" do
      attrs = Map.delete(@valid_attrs, :secret)
      changeset = InboundWebhookConfigSchema.changeset(%InboundWebhookConfigSchema{}, attrs)

      refute changeset.valid?
      assert "can't be blank" in errors_on(changeset).secret
    end

    test "defaults is_active to true" do
      schema = %InboundWebhookConfigSchema{}
      assert schema.is_active == true
    end
  end

  describe "to_entity/1" do
    test "converts schema to domain entity" do
      now = DateTime.utc_now()
      workspace_id = Ecto.UUID.generate()

      schema = %InboundWebhookConfigSchema{
        id: Ecto.UUID.generate(),
        workspace_id: workspace_id,
        secret: "whsec_inbound_secret",
        is_active: true,
        inserted_at: now,
        updated_at: now
      }

      entity = InboundWebhookConfigSchema.to_entity(schema)

      assert entity.__struct__ == Webhooks.Domain.Entities.InboundWebhookConfig
      assert entity.id == schema.id
      assert entity.workspace_id == workspace_id
      assert entity.secret == "whsec_inbound_secret"
      assert entity.is_active == true
    end
  end

  describe "database integration" do
    test "inserts config and enforces unique workspace_id" do
      {:ok, _config} =
        %InboundWebhookConfigSchema{}
        |> InboundWebhookConfigSchema.changeset(@valid_attrs)
        |> Repo.insert()

      # Second insert with same workspace_id should fail
      {:error, changeset} =
        %InboundWebhookConfigSchema{}
        |> InboundWebhookConfigSchema.changeset(@valid_attrs)
        |> Repo.insert()

      assert "has already been taken" in errors_on(changeset).workspace_id
    end
  end
end
