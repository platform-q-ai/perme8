defmodule Webhooks.Infrastructure.Queries.SubscriptionQueriesTest do
  use Webhooks.DataCase, async: true

  alias Webhooks.Infrastructure.Queries.SubscriptionQueries
  alias Webhooks.Infrastructure.Schemas.SubscriptionSchema

  @workspace_id_1 Ecto.UUID.generate()
  @workspace_id_2 Ecto.UUID.generate()

  setup do
    # Insert some subscriptions
    {:ok, active_sub} =
      insert_subscription(%{
        url: "https://example.com/hook1",
        secret: "secret1_long_enough_for_tests",
        event_types: ["projects.project_created", "documents.document_created"],
        workspace_id: @workspace_id_1,
        is_active: true
      })

    {:ok, inactive_sub} =
      insert_subscription(%{
        url: "https://example.com/hook2",
        secret: "secret2_long_enough_for_tests",
        event_types: ["projects.project_created"],
        workspace_id: @workspace_id_1,
        is_active: false
      })

    {:ok, other_workspace_sub} =
      insert_subscription(%{
        url: "https://other.com/hook",
        secret: "secret3_long_enough_for_tests",
        event_types: ["projects.project_deleted"],
        workspace_id: @workspace_id_2,
        is_active: true
      })

    %{
      active_sub: active_sub,
      inactive_sub: inactive_sub,
      other_workspace_sub: other_workspace_sub
    }
  end

  describe "for_workspace/2" do
    test "filters by workspace_id", %{active_sub: active_sub, inactive_sub: inactive_sub} do
      results =
        SubscriptionSchema
        |> SubscriptionQueries.for_workspace(@workspace_id_1)
        |> Repo.all()

      ids = Enum.map(results, & &1.id)
      assert active_sub.id in ids
      assert inactive_sub.id in ids
      assert length(ids) == 2
    end
  end

  describe "active/1" do
    test "filters only active subscriptions", %{active_sub: active_sub} do
      results =
        SubscriptionSchema
        |> SubscriptionQueries.for_workspace(@workspace_id_1)
        |> SubscriptionQueries.active()
        |> Repo.all()

      ids = Enum.map(results, & &1.id)
      assert active_sub.id in ids
      assert length(ids) == 1
    end
  end

  describe "by_id/2" do
    test "finds by ID", %{active_sub: active_sub} do
      result =
        SubscriptionSchema
        |> SubscriptionQueries.by_id(active_sub.id)
        |> Repo.one()

      assert result.id == active_sub.id
    end

    test "returns nil for non-existent ID" do
      result =
        SubscriptionSchema
        |> SubscriptionQueries.by_id(Ecto.UUID.generate())
        |> Repo.one()

      assert result == nil
    end
  end

  describe "by_id_and_workspace/3" do
    test "finds by ID within specific workspace", %{active_sub: active_sub} do
      result =
        SubscriptionSchema
        |> SubscriptionQueries.by_id_and_workspace(active_sub.id, @workspace_id_1)
        |> Repo.one()

      assert result.id == active_sub.id
    end

    test "returns nil when ID belongs to different workspace", %{active_sub: active_sub} do
      result =
        SubscriptionSchema
        |> SubscriptionQueries.by_id_and_workspace(active_sub.id, @workspace_id_2)
        |> Repo.one()

      assert result == nil
    end
  end

  describe "matching_event_type/2" do
    test "filters subscriptions whose event_types array contains the given type", %{
      active_sub: active_sub
    } do
      results =
        SubscriptionSchema
        |> SubscriptionQueries.for_workspace(@workspace_id_1)
        |> SubscriptionQueries.active()
        |> SubscriptionQueries.matching_event_type("documents.document_created")
        |> Repo.all()

      ids = Enum.map(results, & &1.id)
      assert active_sub.id in ids
      assert length(ids) == 1
    end

    test "returns empty when no subscriptions match event type" do
      results =
        SubscriptionSchema
        |> SubscriptionQueries.for_workspace(@workspace_id_1)
        |> SubscriptionQueries.matching_event_type("nonexistent.event")
        |> Repo.all()

      assert results == []
    end
  end

  defp insert_subscription(attrs) do
    %SubscriptionSchema{}
    |> SubscriptionSchema.changeset(attrs)
    |> Repo.insert()
  end
end
