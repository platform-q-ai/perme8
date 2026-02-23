defmodule Webhooks.Infrastructure.Repositories.SubscriptionRepositoryTest do
  use Webhooks.DataCase, async: true

  alias Webhooks.Infrastructure.Repositories.SubscriptionRepository
  alias Webhooks.Infrastructure.Schemas.SubscriptionSchema
  alias Webhooks.Domain.Entities.Subscription

  @workspace_id Ecto.UUID.generate()
  @created_by_id Ecto.UUID.generate()

  describe "insert/2" do
    test "creates and returns domain entity" do
      attrs = %{
        url: "https://example.com/webhook",
        secret: "whsec_test_secret_long_enough",
        event_types: ["projects.project_created"],
        workspace_id: @workspace_id,
        created_by_id: @created_by_id
      }

      assert {:ok, %Subscription{} = entity} = SubscriptionRepository.insert(attrs, Repo)

      assert entity.id != nil
      assert entity.url == "https://example.com/webhook"
      assert entity.secret == "whsec_test_secret_long_enough"
      assert entity.event_types == ["projects.project_created"]
      assert entity.workspace_id == @workspace_id
      assert entity.is_active == true
    end

    test "returns changeset error for invalid attrs" do
      attrs = %{url: "not-a-url", workspace_id: @workspace_id}

      assert {:error, %Ecto.Changeset{}} = SubscriptionRepository.insert(attrs, Repo)
    end
  end

  describe "update/3" do
    test "updates and returns domain entity" do
      {:ok, sub} = insert_subscription()

      assert {:ok, %Subscription{} = updated} =
               SubscriptionRepository.update(sub.id, %{url: "https://new-url.com/hook"}, Repo)

      assert updated.url == "https://new-url.com/hook"
      assert updated.id == sub.id
    end

    test "returns :not_found for non-existent subscription" do
      assert {:error, :not_found} =
               SubscriptionRepository.update(Ecto.UUID.generate(), %{url: "https://x.com"}, Repo)
    end
  end

  describe "delete/2" do
    test "removes record and returns domain entity" do
      {:ok, sub} = insert_subscription()

      assert {:ok, %Subscription{} = deleted} = SubscriptionRepository.delete(sub.id, Repo)
      assert deleted.id == sub.id

      # Verify it's actually deleted
      assert Repo.get(SubscriptionSchema, sub.id) == nil
    end

    test "returns :not_found for non-existent subscription" do
      assert {:error, :not_found} = SubscriptionRepository.delete(Ecto.UUID.generate(), Repo)
    end
  end

  describe "get_by_id/3" do
    test "returns domain entity" do
      {:ok, sub} = insert_subscription()

      assert {:ok, %Subscription{} = entity} =
               SubscriptionRepository.get_by_id(sub.id, @workspace_id, Repo)

      assert entity.id == sub.id
      assert entity.workspace_id == @workspace_id
    end

    test "returns :not_found for missing subscription" do
      assert {:error, :not_found} =
               SubscriptionRepository.get_by_id(Ecto.UUID.generate(), @workspace_id, Repo)
    end

    test "returns :not_found when workspace_id doesn't match" do
      {:ok, sub} = insert_subscription()

      assert {:error, :not_found} =
               SubscriptionRepository.get_by_id(sub.id, Ecto.UUID.generate(), Repo)
    end

    test "returns entity when workspace_id is nil (no workspace filter)" do
      {:ok, sub} = insert_subscription()

      assert {:ok, %Subscription{} = entity} =
               SubscriptionRepository.get_by_id(sub.id, nil, Repo)

      assert entity.id == sub.id
    end
  end

  describe "list_for_workspace/3" do
    test "returns list of domain entities" do
      {:ok, _sub1} = insert_subscription()
      {:ok, _sub2} = insert_subscription(%{url: "https://other.com/hook"})

      assert {:ok, subscriptions} =
               SubscriptionRepository.list_for_workspace(@workspace_id, Repo)

      assert length(subscriptions) == 2
      assert Enum.all?(subscriptions, &match?(%Subscription{}, &1))
    end

    test "returns empty list for workspace with no subscriptions" do
      assert {:ok, []} =
               SubscriptionRepository.list_for_workspace(Ecto.UUID.generate(), Repo)
    end
  end

  describe "list_active_for_event_type/3" do
    test "returns active subscriptions matching event type" do
      {:ok, sub} =
        insert_subscription(%{
          event_types: ["projects.project_created", "documents.document_created"]
        })

      # Insert inactive subscription with same event type
      insert_subscription(%{
        url: "https://inactive.com/hook",
        is_active: false,
        event_types: ["projects.project_created"]
      })

      assert {:ok, results} =
               SubscriptionRepository.list_active_for_event_type(
                 @workspace_id,
                 "projects.project_created",
                 Repo
               )

      ids = Enum.map(results, & &1.id)
      assert sub.id in ids
      # Only active should be returned
      assert length(results) == 1
    end
  end

  defp insert_subscription(overrides \\ %{}) do
    attrs =
      Map.merge(
        %{
          url: "https://example.com/webhook",
          secret: "whsec_test_secret_long_enough",
          event_types: ["projects.project_created"],
          workspace_id: @workspace_id,
          created_by_id: @created_by_id
        },
        overrides
      )

    %SubscriptionSchema{}
    |> SubscriptionSchema.changeset(attrs)
    |> Repo.insert()
    |> case do
      {:ok, schema} -> {:ok, SubscriptionSchema.to_entity(schema)}
      error -> error
    end
  end
end
