defmodule Jarga.Webhooks.Infrastructure.Repositories.DeliveryRepositoryTest do
  use Jarga.DataCase, async: true

  import Jarga.AccountsFixtures
  import Jarga.WorkspacesFixtures
  import Jarga.WebhookFixtures

  alias Jarga.Webhooks.Infrastructure.Repositories.DeliveryRepository
  alias Jarga.Webhooks.Domain.Entities.WebhookDelivery

  setup do
    user = user_fixture()
    workspace = workspace_fixture(user)

    sub =
      webhook_subscription_fixture(%{
        workspace_id: workspace.id,
        created_by_id: user.id
      })

    %{user: user, workspace: workspace, subscription: sub}
  end

  describe "insert/2" do
    test "creates delivery record and returns domain entity", %{subscription: sub} do
      attrs = %{
        webhook_subscription_id: sub.id,
        event_type: "projects.project_created",
        payload: %{"project_id" => "abc123"},
        status: "pending",
        attempts: 1,
        max_attempts: 5
      }

      assert {:ok, %WebhookDelivery{} = delivery} = DeliveryRepository.insert(attrs)
      assert delivery.webhook_subscription_id == sub.id
      assert delivery.event_type == "projects.project_created"
      assert delivery.id != nil
    end
  end

  describe "update/3" do
    test "updates delivery fields and returns domain entity", %{subscription: sub} do
      schema =
        webhook_delivery_fixture(%{
          webhook_subscription_id: sub.id,
          status: "pending",
          attempts: 1
        })

      assert {:ok, %WebhookDelivery{} = updated} =
               DeliveryRepository.update(schema, %{
                 status: "success",
                 response_code: 200,
                 response_body: "OK",
                 attempts: 2
               })

      assert updated.status == "success"
      assert updated.response_code == 200
      assert updated.attempts == 2
    end
  end

  describe "get/2" do
    test "returns delivery domain entity when found", %{subscription: sub} do
      schema =
        webhook_delivery_fixture(%{
          webhook_subscription_id: sub.id
        })

      assert %WebhookDelivery{} = delivery = DeliveryRepository.get(schema.id)
      assert delivery.id == schema.id
    end

    test "returns nil when not found" do
      assert DeliveryRepository.get(Ecto.UUID.generate()) == nil
    end
  end

  describe "list_for_subscription/2" do
    test "returns domain entities for subscription", %{subscription: sub} do
      webhook_delivery_fixture(%{webhook_subscription_id: sub.id, event_type: "a"})
      webhook_delivery_fixture(%{webhook_subscription_id: sub.id, event_type: "b"})

      results = DeliveryRepository.list_for_subscription(sub.id)
      assert length(results) == 2
      assert Enum.all?(results, &match?(%WebhookDelivery{}, &1))
    end
  end

  describe "list_pending_retries/1" do
    test "returns pending deliveries ready for retry", %{subscription: sub} do
      past = DateTime.add(DateTime.utc_now(), -60, :second) |> DateTime.truncate(:second)

      ready =
        webhook_delivery_fixture(%{
          webhook_subscription_id: sub.id,
          status: "pending",
          next_retry_at: past,
          attempts: 1
        })

      _success =
        webhook_delivery_fixture(%{
          webhook_subscription_id: sub.id,
          status: "success",
          attempts: 1
        })

      results = DeliveryRepository.list_pending_retries()
      ids = Enum.map(results, & &1.id)
      assert ready.id in ids
      assert Enum.all?(results, &match?(%WebhookDelivery{}, &1))
    end
  end
end
