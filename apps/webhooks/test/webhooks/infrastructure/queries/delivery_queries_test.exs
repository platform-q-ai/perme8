defmodule Webhooks.Infrastructure.Queries.DeliveryQueriesTest do
  use Webhooks.DataCase, async: true

  alias Webhooks.Infrastructure.Queries.DeliveryQueries
  alias Webhooks.Infrastructure.Schemas.{DeliverySchema, SubscriptionSchema}

  setup do
    workspace_id = Ecto.UUID.generate()

    {:ok, subscription} =
      insert_subscription(%{
        url: "https://example.com/hook",
        secret: "secret_long_enough_for_tests",
        event_types: ["projects.project_created"],
        workspace_id: workspace_id
      })

    {:ok, another_subscription} =
      insert_subscription(%{
        url: "https://other.com/hook",
        secret: "another_secret_long_enough",
        event_types: ["documents.document_created"],
        workspace_id: workspace_id
      })

    past = DateTime.add(DateTime.utc_now(), -60, :second)
    future = DateTime.add(DateTime.utc_now(), 3600, :second)

    {:ok, pending_past} =
      insert_delivery(%{
        subscription_id: subscription.id,
        event_type: "projects.project_created",
        payload: %{},
        status: "pending",
        next_retry_at: past,
        attempts: 1
      })

    {:ok, pending_future} =
      insert_delivery(%{
        subscription_id: subscription.id,
        event_type: "projects.project_created",
        payload: %{},
        status: "pending",
        next_retry_at: future,
        attempts: 1
      })

    {:ok, success_delivery} =
      insert_delivery(%{
        subscription_id: subscription.id,
        event_type: "projects.project_created",
        payload: %{},
        status: "success",
        response_code: 200,
        attempts: 1
      })

    {:ok, other_sub_delivery} =
      insert_delivery(%{
        subscription_id: another_subscription.id,
        event_type: "documents.document_created",
        payload: %{},
        status: "pending"
      })

    %{
      subscription: subscription,
      pending_past: pending_past,
      pending_future: pending_future,
      success_delivery: success_delivery,
      other_sub_delivery: other_sub_delivery
    }
  end

  describe "for_subscription/2" do
    test "filters by subscription_id", %{
      subscription: subscription,
      pending_past: pending_past,
      pending_future: pending_future,
      success_delivery: success_delivery
    } do
      results =
        DeliverySchema
        |> DeliveryQueries.for_subscription(subscription.id)
        |> Repo.all()

      ids = Enum.map(results, & &1.id)
      assert pending_past.id in ids
      assert pending_future.id in ids
      assert success_delivery.id in ids
      assert length(ids) == 3
    end
  end

  describe "by_id/2" do
    test "finds by ID", %{success_delivery: success_delivery} do
      result =
        DeliverySchema
        |> DeliveryQueries.by_id(success_delivery.id)
        |> Repo.one()

      assert result.id == success_delivery.id
    end

    test "returns nil for non-existent ID" do
      result =
        DeliverySchema
        |> DeliveryQueries.by_id(Ecto.UUID.generate())
        |> Repo.one()

      assert result == nil
    end
  end

  describe "pending_retries/1" do
    test "finds deliveries with status pending and next_retry_at <= now", %{
      pending_past: pending_past
    } do
      results =
        DeliverySchema
        |> DeliveryQueries.pending_retries()
        |> Repo.all()

      ids = Enum.map(results, & &1.id)
      assert pending_past.id in ids
      # pending_future should NOT be included (retry time is in the future)
      refute Enum.any?(results, fn d ->
               d.next_retry_at != nil and
                 DateTime.compare(d.next_retry_at, DateTime.utc_now()) == :gt
             end)
    end
  end

  describe "ordered/1" do
    test "orders by inserted_at desc", %{
      subscription: subscription,
      pending_past: _,
      pending_future: _,
      success_delivery: _
    } do
      results =
        DeliverySchema
        |> DeliveryQueries.for_subscription(subscription.id)
        |> DeliveryQueries.ordered()
        |> Repo.all()

      # The last inserted should be first
      inserted_ats = Enum.map(results, & &1.inserted_at)
      assert inserted_ats == Enum.sort(inserted_ats, {:desc, DateTime})
    end
  end

  defp insert_subscription(attrs) do
    %SubscriptionSchema{}
    |> SubscriptionSchema.changeset(attrs)
    |> Repo.insert()
  end

  defp insert_delivery(attrs) do
    %DeliverySchema{}
    |> DeliverySchema.changeset(attrs)
    |> Repo.insert()
  end
end
