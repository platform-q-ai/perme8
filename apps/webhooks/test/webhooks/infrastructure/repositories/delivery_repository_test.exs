defmodule Webhooks.Infrastructure.Repositories.DeliveryRepositoryTest do
  use Webhooks.DataCase, async: true

  alias Webhooks.Infrastructure.Repositories.DeliveryRepository
  alias Webhooks.Infrastructure.Schemas.{DeliverySchema, SubscriptionSchema}
  alias Webhooks.Domain.Entities.Delivery

  setup do
    {:ok, subscription} =
      %SubscriptionSchema{}
      |> SubscriptionSchema.changeset(%{
        url: "https://example.com/webhook",
        secret: "whsec_test_secret_long_enough",
        event_types: ["projects.project_created"],
        workspace_id: Ecto.UUID.generate()
      })
      |> Repo.insert()

    %{subscription: subscription}
  end

  describe "insert/2" do
    test "creates delivery record and returns domain entity", %{subscription: subscription} do
      attrs = %{
        subscription_id: subscription.id,
        event_type: "projects.project_created",
        payload: %{"project_id" => "123"},
        status: "pending"
      }

      assert {:ok, %Delivery{} = entity} = DeliveryRepository.insert(attrs, Repo)

      assert entity.id != nil
      assert entity.subscription_id == subscription.id
      assert entity.event_type == "projects.project_created"
      assert entity.payload == %{"project_id" => "123"}
      assert entity.status == "pending"
    end

    test "returns changeset error for invalid attrs" do
      assert {:error, %Ecto.Changeset{}} = DeliveryRepository.insert(%{}, Repo)
    end
  end

  describe "get_by_id/3" do
    test "returns delivery as domain entity", %{subscription: subscription} do
      {:ok, delivery} = create_delivery(subscription)

      assert {:ok, %Delivery{} = entity} =
               DeliveryRepository.get_by_id(delivery.id, subscription.workspace_id, Repo)

      assert entity.id == delivery.id
    end

    test "returns :not_found for missing delivery", %{subscription: subscription} do
      assert {:error, :not_found} =
               DeliveryRepository.get_by_id(Ecto.UUID.generate(), subscription.workspace_id, Repo)
    end
  end

  describe "list_for_subscription/3" do
    test "returns deliveries for a subscription", %{subscription: subscription} do
      {:ok, _d1} = create_delivery(subscription)
      {:ok, _d2} = create_delivery(subscription, %{event_type: "documents.document_created"})

      assert {:ok, deliveries} =
               DeliveryRepository.list_for_subscription(subscription.id, Repo)

      assert length(deliveries) == 2
      assert Enum.all?(deliveries, &match?(%Delivery{}, &1))
    end

    test "returns empty list when no deliveries exist" do
      assert {:ok, []} =
               DeliveryRepository.list_for_subscription(Ecto.UUID.generate(), Repo)
    end
  end

  describe "update_status/4" do
    test "updates status, response_code, attempts, next_retry_at", %{subscription: subscription} do
      {:ok, delivery} = create_delivery(subscription)
      next_retry = DateTime.add(DateTime.utc_now(), 60, :second)

      update_attrs = %{
        status: "pending",
        response_code: 500,
        attempts: 2,
        next_retry_at: next_retry
      }

      assert {:ok, %Delivery{} = updated} =
               DeliveryRepository.update_status(delivery.id, update_attrs, Repo)

      assert updated.status == "pending"
      assert updated.response_code == 500
      assert updated.attempts == 2
      assert updated.next_retry_at != nil
    end

    test "returns :not_found for missing delivery" do
      assert {:error, :not_found} =
               DeliveryRepository.update_status(
                 Ecto.UUID.generate(),
                 %{status: "failed"},
                 Repo
               )
    end
  end

  describe "list_pending_retries/1" do
    test "returns deliveries with pending status and past next_retry_at", %{
      subscription: subscription
    } do
      past = DateTime.add(DateTime.utc_now(), -60, :second)
      future = DateTime.add(DateTime.utc_now(), 3600, :second)

      {:ok, past_delivery} =
        create_delivery(subscription, %{status: "pending", next_retry_at: past, attempts: 1})

      {:ok, _future_delivery} =
        create_delivery(subscription, %{status: "pending", next_retry_at: future, attempts: 1})

      {:ok, _success_delivery} =
        create_delivery(subscription, %{status: "success", attempts: 1})

      assert {:ok, retries} = DeliveryRepository.list_pending_retries(Repo)

      ids = Enum.map(retries, & &1.id)
      assert past_delivery.id in ids
      assert Enum.all?(retries, &match?(%Delivery{}, &1))
    end
  end

  defp create_delivery(subscription, overrides \\ %{}) do
    attrs =
      Map.merge(
        %{
          subscription_id: subscription.id,
          event_type: "projects.project_created",
          payload: %{"project_id" => "123"}
        },
        overrides
      )

    %DeliverySchema{}
    |> DeliverySchema.changeset(attrs)
    |> Repo.insert()
    |> case do
      {:ok, schema} -> {:ok, DeliverySchema.to_entity(schema)}
      error -> error
    end
  end
end
