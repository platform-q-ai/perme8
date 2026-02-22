defmodule Jarga.Webhooks.Application.UseCases.ProcessInboundWebhookTest do
  use Jarga.DataCase, async: true

  import Mox

  alias Jarga.Webhooks.Application.UseCases.ProcessInboundWebhook
  alias Jarga.Webhooks.Domain.Entities.InboundWebhook
  alias Jarga.Webhooks.Domain.Events.InboundWebhookReceived
  alias Jarga.Webhooks.Domain.Policies.SignaturePolicy
  alias Jarga.Webhooks.Mocks.MockInboundWebhookRepository
  alias Perme8.Events.TestEventBus

  setup :verify_on_exit!

  setup do
    test_name = :"test_event_bus_#{System.unique_integer([:positive])}"
    {:ok, _pid} = TestEventBus.start_link(name: test_name)
    {:ok, event_bus_name: test_name}
  end

  defp base_opts(ctx) do
    [
      inbound_webhook_repository: MockInboundWebhookRepository,
      event_bus: TestEventBus,
      event_bus_opts: [name: ctx.event_bus_name]
    ]
  end

  @secret "whsec_test_inbound_secret"

  describe "execute/2 - valid signature" do
    test "processes valid webhook and records audit log", ctx do
      raw_body = ~s({"event_type":"stripe.payment_succeeded","data":{"amount":1000}})
      signature = SignaturePolicy.build_signature_header(raw_body, @secret)

      inbound = %InboundWebhook{
        id: Ecto.UUID.generate(),
        workspace_id: "ws-123",
        event_type: "stripe.payment_succeeded",
        signature_valid: true
      }

      MockInboundWebhookRepository
      |> expect(:insert, fn attrs, _opts ->
        assert attrs.signature_valid == true
        assert attrs.event_type == "stripe.payment_succeeded"
        assert attrs.workspace_id == "ws-123"
        {:ok, inbound}
      end)

      params = %{
        workspace_id: "ws-123",
        raw_body: raw_body,
        signature: signature,
        source_ip: "192.168.1.1",
        workspace_secret: @secret
      }

      assert {:ok, result} = ProcessInboundWebhook.execute(params, base_opts(ctx))
      assert result.signature_valid == true

      events = TestEventBus.get_events(name: ctx.event_bus_name)
      assert [%InboundWebhookReceived{signature_valid: true}] = events
    end
  end

  describe "execute/2 - invalid signature" do
    test "returns error for invalid signature", ctx do
      raw_body = ~s({"event_type":"test.event"})

      params = %{
        workspace_id: "ws-123",
        raw_body: raw_body,
        signature: "sha256=invalid_signature",
        source_ip: "192.168.1.1",
        workspace_secret: @secret
      }

      assert {:error, :invalid_signature} = ProcessInboundWebhook.execute(params, base_opts(ctx))
    end
  end

  describe "execute/2 - missing signature" do
    test "returns error for missing signature", ctx do
      raw_body = ~s({"event_type":"test.event"})

      params = %{
        workspace_id: "ws-123",
        raw_body: raw_body,
        signature: nil,
        source_ip: "192.168.1.1",
        workspace_secret: @secret
      }

      assert {:error, :missing_signature} = ProcessInboundWebhook.execute(params, base_opts(ctx))
    end
  end

  describe "execute/2 - malformed payload" do
    test "returns error for invalid JSON", ctx do
      raw_body = "not valid json {"
      signature = SignaturePolicy.build_signature_header(raw_body, @secret)

      params = %{
        workspace_id: "ws-123",
        raw_body: raw_body,
        signature: signature,
        source_ip: "192.168.1.1",
        workspace_secret: @secret
      }

      assert {:error, :invalid_payload} = ProcessInboundWebhook.execute(params, base_opts(ctx))
    end
  end
end
