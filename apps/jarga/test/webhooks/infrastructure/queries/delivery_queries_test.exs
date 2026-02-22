defmodule Jarga.Webhooks.Infrastructure.Queries.DeliveryQueriesTest do
  use Jarga.DataCase, async: true

  import Jarga.AccountsFixtures
  import Jarga.WorkspacesFixtures
  import Jarga.WebhookFixtures

  alias Jarga.Webhooks.Infrastructure.Queries.DeliveryQueries

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

  describe "for_subscription/2" do
    test "filters deliveries by webhook_subscription_id", %{subscription: sub} do
      delivery =
        webhook_delivery_fixture(%{
          webhook_subscription_id: sub.id,
          event_type: "projects.project_created"
        })

      results =
        DeliveryQueries.for_subscription(sub.id)
        |> Repo.all()

      assert length(results) == 1
      assert hd(results).id == delivery.id
    end
  end

  describe "by_id/2" do
    test "filters by id", %{subscription: sub} do
      delivery =
        webhook_delivery_fixture(%{
          webhook_subscription_id: sub.id
        })

      result =
        DeliveryQueries.by_id(delivery.id)
        |> Repo.one()

      assert result.id == delivery.id
    end
  end

  describe "pending_retries/1" do
    test "returns deliveries with status pending and next_retry_at <= now", %{subscription: sub} do
      past = DateTime.add(DateTime.utc_now(), -60, :second) |> DateTime.truncate(:second)
      future = DateTime.add(DateTime.utc_now(), 3600, :second) |> DateTime.truncate(:second)

      ready =
        webhook_delivery_fixture(%{
          webhook_subscription_id: sub.id,
          status: "pending",
          next_retry_at: past,
          attempts: 1
        })

      _not_yet =
        webhook_delivery_fixture(%{
          webhook_subscription_id: sub.id,
          status: "pending",
          next_retry_at: future,
          attempts: 1
        })

      _success =
        webhook_delivery_fixture(%{
          webhook_subscription_id: sub.id,
          status: "success",
          next_retry_at: nil,
          attempts: 1
        })

      results = DeliveryQueries.pending_retries() |> Repo.all()
      ids = Enum.map(results, & &1.id)
      assert ready.id in ids
      refute future in ids
    end
  end

  describe "ordered/1" do
    test "orders by inserted_at desc", %{subscription: sub} do
      _d1 =
        webhook_delivery_fixture(%{
          webhook_subscription_id: sub.id,
          event_type: "a"
        })

      d2 =
        webhook_delivery_fixture(%{
          webhook_subscription_id: sub.id,
          event_type: "b"
        })

      # Manually update d2 to have a later timestamp
      now = DateTime.utc_now() |> DateTime.truncate(:second)
      later = DateTime.add(now, 60, :second)

      Repo.update_all(
        from(d in Jarga.Webhooks.Infrastructure.Schemas.WebhookDeliverySchema,
          where: d.id == ^d2.id
        ),
        set: [inserted_at: later]
      )

      results =
        DeliveryQueries.for_subscription(sub.id)
        |> DeliveryQueries.ordered()
        |> Repo.all()

      # d2 has later timestamp, should come first
      assert [first | _] = results
      assert first.id == d2.id
    end
  end
end
