defmodule Jarga.Webhooks.Infrastructure.Schemas.InboundWebhookSchemaTest do
  use Jarga.DataCase, async: true

  alias Jarga.Webhooks.Infrastructure.Schemas.InboundWebhookSchema

  @valid_attrs %{
    workspace_id: Ecto.UUID.generate(),
    event_type: "external.payment_received",
    payload: %{"amount" => 100},
    source_ip: "192.168.1.1",
    signature_valid: true,
    handler_result: "processed",
    received_at: DateTime.utc_now() |> DateTime.truncate(:second)
  }

  describe "changeset/2" do
    test "valid changeset with all fields" do
      changeset = InboundWebhookSchema.changeset(%InboundWebhookSchema{}, @valid_attrs)
      assert changeset.valid?
    end

    test "requires workspace_id" do
      attrs = Map.delete(@valid_attrs, :workspace_id)
      changeset = InboundWebhookSchema.changeset(%InboundWebhookSchema{}, attrs)
      refute changeset.valid?
      assert %{workspace_id: ["can't be blank"]} = errors_on(changeset)
    end

    test "requires received_at" do
      attrs = Map.delete(@valid_attrs, :received_at)
      changeset = InboundWebhookSchema.changeset(%InboundWebhookSchema{}, attrs)
      refute changeset.valid?
      assert %{received_at: ["can't be blank"]} = errors_on(changeset)
    end

    test "signature_valid defaults to false" do
      attrs = Map.delete(@valid_attrs, :signature_valid)
      changeset = InboundWebhookSchema.changeset(%InboundWebhookSchema{}, attrs)
      assert changeset.valid?
    end
  end
end
