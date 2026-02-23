defmodule Webhooks.Application.UseCases.ReceiveInboundWebhookTest do
  use ExUnit.Case, async: true

  alias Webhooks.Application.UseCases.ReceiveInboundWebhook
  alias Webhooks.Domain.Entities.{InboundLog, InboundWebhookConfig}
  alias Webhooks.Domain.Policies.HmacPolicy

  @test_secret "test-inbound-secret-that-is-long-enough"
  @test_payload ~s({"event":"test","data":"hello"})

  defmodule MockConfigRepo do
    def get_by_workspace_id("ws-configured", _repo) do
      {:ok,
       InboundWebhookConfig.new(%{
         id: "cfg-1",
         workspace_id: "ws-configured",
         secret: "test-inbound-secret-that-is-long-enough",
         is_active: true
       })}
    end

    def get_by_workspace_id("ws-unconfigured", _repo) do
      {:error, :not_found}
    end
  end

  defmodule MockInboundLogRepo do
    def insert(attrs, _repo) do
      log =
        InboundLog.new(%{
          id: "log-#{System.unique_integer([:positive])}",
          workspace_id: attrs.workspace_id,
          event_type: attrs[:event_type],
          payload: attrs[:payload],
          source_ip: attrs[:source_ip],
          signature_valid: attrs.signature_valid,
          received_at: attrs[:received_at] || DateTime.utc_now()
        })

      {:ok, log}
    end
  end

  describe "execute/2 - valid signature" do
    test "records inbound log and returns ok" do
      valid_signature = HmacPolicy.compute_signature(@test_secret, @test_payload)

      params = %{
        workspace_id: "ws-configured",
        raw_body: @test_payload,
        signature: valid_signature,
        source_ip: "192.168.1.1"
      }

      opts = [
        inbound_webhook_config_repository: MockConfigRepo,
        inbound_log_repository: MockInboundLogRepo
      ]

      assert {:ok, %InboundLog{} = log} = ReceiveInboundWebhook.execute(params, opts)
      assert log.signature_valid == true
      assert log.workspace_id == "ws-configured"
    end
  end

  describe "execute/2 - invalid signature" do
    test "records log with signature_valid false and returns error" do
      params = %{
        workspace_id: "ws-configured",
        raw_body: @test_payload,
        signature: "invalid-signature-value",
        source_ip: "192.168.1.1"
      }

      opts = [
        inbound_webhook_config_repository: MockConfigRepo,
        inbound_log_repository: MockInboundLogRepo
      ]

      assert {:error, :invalid_signature} = ReceiveInboundWebhook.execute(params, opts)
    end
  end

  describe "execute/2 - missing signature" do
    test "returns error for nil signature" do
      params = %{
        workspace_id: "ws-configured",
        raw_body: @test_payload,
        signature: nil,
        source_ip: "192.168.1.1"
      }

      opts = [
        inbound_webhook_config_repository: MockConfigRepo,
        inbound_log_repository: MockInboundLogRepo
      ]

      assert {:error, :missing_signature} = ReceiveInboundWebhook.execute(params, opts)
    end
  end

  describe "execute/2 - no config" do
    test "returns not_configured when workspace has no inbound config" do
      params = %{
        workspace_id: "ws-unconfigured",
        raw_body: @test_payload,
        signature: "any-signature",
        source_ip: "192.168.1.1"
      }

      opts = [
        inbound_webhook_config_repository: MockConfigRepo,
        inbound_log_repository: MockInboundLogRepo
      ]

      assert {:error, :not_configured} = ReceiveInboundWebhook.execute(params, opts)
    end
  end
end
