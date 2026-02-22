defmodule Jarga.Webhooks.Application.Behaviours.BehavioursTest do
  use ExUnit.Case, async: true

  alias Jarga.Webhooks.Application.Behaviours.WebhookRepositoryBehaviour
  alias Jarga.Webhooks.Application.Behaviours.DeliveryRepositoryBehaviour
  alias Jarga.Webhooks.Application.Behaviours.InboundWebhookRepositoryBehaviour
  alias Jarga.Webhooks.Application.Behaviours.HttpClientBehaviour

  describe "WebhookRepositoryBehaviour" do
    test "defines expected callbacks" do
      callbacks = WebhookRepositoryBehaviour.behaviour_info(:callbacks)

      assert {:insert, 2} in callbacks
      assert {:update, 3} in callbacks
      assert {:delete, 2} in callbacks
      assert {:get, 2} in callbacks
      assert {:list_for_workspace, 2} in callbacks
      assert {:list_active_for_event, 3} in callbacks
    end
  end

  describe "DeliveryRepositoryBehaviour" do
    test "defines expected callbacks" do
      callbacks = DeliveryRepositoryBehaviour.behaviour_info(:callbacks)

      assert {:insert, 2} in callbacks
      assert {:update, 3} in callbacks
      assert {:get, 2} in callbacks
      assert {:list_for_subscription, 2} in callbacks
      assert {:list_pending_retries, 1} in callbacks
    end
  end

  describe "InboundWebhookRepositoryBehaviour" do
    test "defines expected callbacks" do
      callbacks = InboundWebhookRepositoryBehaviour.behaviour_info(:callbacks)

      assert {:insert, 2} in callbacks
      assert {:list_for_workspace, 2} in callbacks
    end
  end

  describe "HttpClientBehaviour" do
    test "defines expected callbacks" do
      callbacks = HttpClientBehaviour.behaviour_info(:callbacks)

      assert {:post, 3} in callbacks
    end
  end
end
