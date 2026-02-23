defmodule Webhooks.Infrastructure.Schemas.InboundLogSchemaTest do
  use Webhooks.DataCase, async: true

  alias Webhooks.Infrastructure.Schemas.InboundLogSchema

  @valid_attrs %{
    workspace_id: Ecto.UUID.generate(),
    event_type: "projects.project_created",
    payload: %{"key" => "value"},
    source_ip: "192.168.1.1",
    signature_valid: true,
    handler_result: "ok",
    received_at: ~U[2026-02-23 12:00:00Z]
  }

  describe "changeset/2" do
    test "valid changeset with required fields" do
      changeset = InboundLogSchema.changeset(%InboundLogSchema{}, @valid_attrs)

      assert changeset.valid?
      assert get_change(changeset, :workspace_id) == @valid_attrs.workspace_id
      assert get_change(changeset, :received_at) == @valid_attrs.received_at
    end

    test "requires workspace_id" do
      attrs = Map.delete(@valid_attrs, :workspace_id)
      changeset = InboundLogSchema.changeset(%InboundLogSchema{}, attrs)

      refute changeset.valid?
      assert "can't be blank" in errors_on(changeset).workspace_id
    end

    test "requires received_at" do
      attrs = Map.delete(@valid_attrs, :received_at)
      changeset = InboundLogSchema.changeset(%InboundLogSchema{}, attrs)

      refute changeset.valid?
      assert "can't be blank" in errors_on(changeset).received_at
    end

    test "casts payload as map" do
      changeset = InboundLogSchema.changeset(%InboundLogSchema{}, @valid_attrs)

      assert changeset.valid?
      assert get_change(changeset, :payload) == %{"key" => "value"}
    end
  end

  describe "to_entity/1" do
    test "converts schema to domain entity" do
      now = DateTime.utc_now()
      workspace_id = Ecto.UUID.generate()

      schema = %InboundLogSchema{
        id: Ecto.UUID.generate(),
        workspace_id: workspace_id,
        event_type: "projects.project_created",
        payload: %{"key" => "value"},
        source_ip: "10.0.0.1",
        signature_valid: true,
        handler_result: "ok",
        received_at: now,
        inserted_at: now,
        updated_at: now
      }

      entity = InboundLogSchema.to_entity(schema)

      assert entity.__struct__ == Webhooks.Domain.Entities.InboundLog
      assert entity.id == schema.id
      assert entity.workspace_id == workspace_id
      assert entity.event_type == "projects.project_created"
      assert entity.payload == %{"key" => "value"}
      assert entity.source_ip == "10.0.0.1"
      assert entity.signature_valid == true
      assert entity.handler_result == "ok"
      assert entity.received_at == now
    end
  end

  describe "database integration" do
    test "inserts and retrieves log entry" do
      {:ok, log} =
        %InboundLogSchema{}
        |> InboundLogSchema.changeset(@valid_attrs)
        |> Repo.insert()

      assert log.id != nil
      assert log.workspace_id == @valid_attrs.workspace_id
      assert log.signature_valid == true
    end
  end
end
