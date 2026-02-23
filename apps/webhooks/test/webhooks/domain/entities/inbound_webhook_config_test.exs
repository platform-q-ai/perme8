defmodule Webhooks.Domain.Entities.InboundWebhookConfigTest do
  use ExUnit.Case, async: true

  alias Webhooks.Domain.Entities.InboundWebhookConfig

  describe "new/1" do
    test "creates an inbound webhook config struct with all fields" do
      attrs = %{
        id: "cfg-123",
        workspace_id: "ws-123",
        secret: "whsec_inbound_secret_value_here",
        is_active: true,
        inserted_at: ~U[2026-01-01 00:00:00Z],
        updated_at: ~U[2026-01-01 00:00:00Z]
      }

      config = InboundWebhookConfig.new(attrs)

      assert config.id == "cfg-123"
      assert config.workspace_id == "ws-123"
      assert config.secret == "whsec_inbound_secret_value_here"
      assert config.is_active == true
      assert config.inserted_at == ~U[2026-01-01 00:00:00Z]
      assert config.updated_at == ~U[2026-01-01 00:00:00Z]
    end

    test "defaults is_active to true" do
      config = InboundWebhookConfig.new(%{})

      assert config.is_active == true
    end
  end

  describe "from_schema/1" do
    test "converts a map to a domain entity" do
      schema = %{
        id: "cfg-456",
        workspace_id: "ws-456",
        secret: "another-secret",
        is_active: false,
        inserted_at: ~U[2026-02-01 12:00:00Z],
        updated_at: ~U[2026-02-01 12:00:00Z]
      }

      config = InboundWebhookConfig.from_schema(schema)

      assert %InboundWebhookConfig{} = config
      assert config.id == "cfg-456"
      assert config.workspace_id == "ws-456"
      assert config.secret == "another-secret"
      assert config.is_active == false
    end
  end
end
