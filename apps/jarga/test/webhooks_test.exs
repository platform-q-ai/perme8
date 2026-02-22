defmodule Jarga.WebhooksTest do
  use Jarga.DataCase, async: true

  import Jarga.AccountsFixtures
  import Jarga.WorkspacesFixtures
  import Jarga.WebhookFixtures

  alias Jarga.Webhooks
  alias Jarga.Webhooks.Domain.Policies.SignaturePolicy

  setup do
    user = user_fixture()
    workspace = workspace_fixture(user)
    %{user: user, workspace: workspace}
  end

  describe "create_subscription/4" do
    test "delegates to CreateWebhookSubscription use case", %{user: user, workspace: workspace} do
      attrs = %{
        url: "https://example.com/webhook",
        event_types: ["projects.project_created"]
      }

      assert {:ok, subscription} =
               Webhooks.create_subscription(user, workspace.id, attrs)

      assert subscription.url == "https://example.com/webhook"
      assert subscription.workspace_id == workspace.id
      assert subscription.secret != nil
    end
  end

  describe "list_subscriptions/3" do
    test "delegates to ListWebhookSubscriptions use case", %{user: user, workspace: workspace} do
      webhook_subscription_fixture(%{workspace_id: workspace.id, created_by_id: user.id})

      assert {:ok, subscriptions} = Webhooks.list_subscriptions(user, workspace.id)
      assert length(subscriptions) == 1
    end
  end

  describe "get_subscription/4" do
    test "delegates to GetWebhookSubscription use case", %{user: user, workspace: workspace} do
      sub = webhook_subscription_fixture(%{workspace_id: workspace.id, created_by_id: user.id})

      assert {:ok, subscription} = Webhooks.get_subscription(user, workspace.id, sub.id)
      assert subscription.id == sub.id
    end
  end

  describe "update_subscription/5" do
    test "delegates to UpdateWebhookSubscription use case", %{user: user, workspace: workspace} do
      sub = webhook_subscription_fixture(%{workspace_id: workspace.id, created_by_id: user.id})

      assert {:ok, updated} =
               Webhooks.update_subscription(user, workspace.id, sub.id, %{
                 url: "https://new-url.com/hook"
               })

      assert updated.url == "https://new-url.com/hook"
    end
  end

  describe "delete_subscription/4" do
    test "delegates to DeleteWebhookSubscription use case", %{user: user, workspace: workspace} do
      sub = webhook_subscription_fixture(%{workspace_id: workspace.id, created_by_id: user.id})

      assert {:ok, deleted} = Webhooks.delete_subscription(user, workspace.id, sub.id)
      assert deleted.id == sub.id
    end
  end

  describe "list_deliveries/4" do
    test "delegates to ListDeliveries use case", %{user: user, workspace: workspace} do
      sub = webhook_subscription_fixture(%{workspace_id: workspace.id, created_by_id: user.id})
      webhook_delivery_fixture(%{webhook_subscription_id: sub.id})

      assert {:ok, deliveries} = Webhooks.list_deliveries(user, workspace.id, sub.id)
      assert length(deliveries) == 1
    end
  end

  describe "get_delivery/4" do
    test "delegates to GetDelivery use case", %{user: user, workspace: workspace} do
      sub = webhook_subscription_fixture(%{workspace_id: workspace.id, created_by_id: user.id})
      delivery = webhook_delivery_fixture(%{webhook_subscription_id: sub.id})

      assert {:ok, result} = Webhooks.get_delivery(user, workspace.id, delivery.id)
      assert result.id == delivery.id
    end
  end

  describe "process_inbound_webhook/2" do
    test "delegates to ProcessInboundWebhook use case", %{workspace: workspace} do
      secret = "test_webhook_secret_key"
      payload = Jason.encode!(%{"event_type" => "test.event", "data" => "value"})

      signature = SignaturePolicy.build_signature_header(payload, secret)

      params = %{
        workspace_id: workspace.id,
        raw_body: payload,
        signature: signature,
        source_ip: "127.0.0.1",
        workspace_secret: secret
      }

      assert {:ok, inbound} = Webhooks.process_inbound_webhook(params)
      assert inbound.workspace_id == workspace.id
    end
  end

  describe "list_inbound_logs/3" do
    test "delegates to ListInboundWebhookLogs use case", %{user: user, workspace: workspace} do
      inbound_webhook_fixture(%{workspace_id: workspace.id})

      assert {:ok, logs} = Webhooks.list_inbound_logs(user, workspace.id)
      assert length(logs) == 1
    end
  end
end
