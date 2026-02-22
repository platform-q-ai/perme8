defmodule Jarga.Webhooks.Infrastructure.Repositories.WebhookRepositoryTest do
  use Jarga.DataCase, async: true

  import Jarga.AccountsFixtures
  import Jarga.WorkspacesFixtures
  import Jarga.WebhookFixtures

  alias Jarga.Webhooks.Infrastructure.Repositories.WebhookRepository
  alias Jarga.Webhooks.Domain.Entities.WebhookSubscription

  setup do
    user = user_fixture()
    workspace = workspace_fixture(user)
    %{user: user, workspace: workspace}
  end

  describe "insert/2" do
    test "creates subscription and returns domain entity", %{workspace: workspace, user: user} do
      attrs = %{
        url: "https://example.com/webhook",
        secret: "test_secret_key_32chars_minimum!",
        event_types: ["projects.project_created"],
        is_active: true,
        workspace_id: workspace.id,
        created_by_id: user.id
      }

      assert {:ok, %WebhookSubscription{} = sub} = WebhookRepository.insert(attrs)
      assert sub.url == "https://example.com/webhook"
      assert sub.workspace_id == workspace.id
      assert sub.created_by_id == user.id
      assert sub.id != nil
    end

    test "returns error changeset on invalid data" do
      assert {:error, %Ecto.Changeset{}} = WebhookRepository.insert(%{})
    end
  end

  describe "update/3" do
    test "updates subscription and returns domain entity", %{workspace: workspace, user: user} do
      schema =
        webhook_subscription_fixture(%{
          workspace_id: workspace.id,
          created_by_id: user.id
        })

      assert {:ok, %WebhookSubscription{} = updated} =
               WebhookRepository.update(schema, %{url: "https://new-url.com/hook"})

      assert updated.url == "https://new-url.com/hook"
    end
  end

  describe "delete/2" do
    test "deletes subscription and returns domain entity", %{workspace: workspace, user: user} do
      schema =
        webhook_subscription_fixture(%{
          workspace_id: workspace.id,
          created_by_id: user.id
        })

      assert {:ok, %WebhookSubscription{} = deleted} = WebhookRepository.delete(schema)
      assert deleted.id == schema.id
      assert WebhookRepository.get(schema.id) == nil
    end
  end

  describe "get/2" do
    test "returns domain entity when found", %{workspace: workspace, user: user} do
      schema =
        webhook_subscription_fixture(%{
          workspace_id: workspace.id,
          created_by_id: user.id
        })

      assert %WebhookSubscription{} = sub = WebhookRepository.get(schema.id)
      assert sub.id == schema.id
      assert sub.url == schema.url
    end

    test "returns nil when not found" do
      assert WebhookRepository.get(Ecto.UUID.generate()) == nil
    end
  end

  describe "list_for_workspace/2" do
    test "returns domain entities for workspace", %{workspace: workspace, user: user} do
      webhook_subscription_fixture(%{workspace_id: workspace.id, created_by_id: user.id})
      webhook_subscription_fixture(%{workspace_id: workspace.id, created_by_id: user.id})

      results = WebhookRepository.list_for_workspace(workspace.id)
      assert length(results) == 2
      assert Enum.all?(results, &match?(%WebhookSubscription{}, &1))
    end
  end

  describe "list_active_for_event/3" do
    test "returns matching active subscriptions as domain entities", %{
      workspace: workspace,
      user: user
    } do
      webhook_subscription_fixture(%{
        workspace_id: workspace.id,
        created_by_id: user.id,
        event_types: ["projects.project_created"],
        is_active: true
      })

      _non_matching =
        webhook_subscription_fixture(%{
          workspace_id: workspace.id,
          created_by_id: user.id,
          event_types: ["chat.message_sent"],
          is_active: true
        })

      results =
        WebhookRepository.list_active_for_event(workspace.id, "projects.project_created")

      assert length(results) == 1
      assert Enum.all?(results, &match?(%WebhookSubscription{}, &1))
    end
  end
end
