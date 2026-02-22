defmodule Jarga.Webhooks.Infrastructure.Queries.WebhookQueriesTest do
  use Jarga.DataCase, async: true

  import Jarga.AccountsFixtures
  import Jarga.WorkspacesFixtures
  import Jarga.WebhookFixtures

  alias Jarga.Webhooks.Infrastructure.Queries.WebhookQueries

  setup do
    user = user_fixture()
    workspace = workspace_fixture(user)
    %{user: user, workspace: workspace}
  end

  describe "base/0" do
    test "returns a queryable" do
      assert %Ecto.Query{} = WebhookQueries.base() |> Ecto.Queryable.to_query()
    end
  end

  describe "for_workspace/2" do
    test "filters by workspace_id", %{workspace: workspace, user: user} do
      sub =
        webhook_subscription_fixture(%{
          workspace_id: workspace.id,
          created_by_id: user.id
        })

      # Create another workspace with a subscription that should NOT be returned
      other_workspace = workspace_fixture(user, %{name: "Other Workspace"})

      _other =
        webhook_subscription_fixture(%{
          workspace_id: other_workspace.id,
          created_by_id: user.id
        })

      results =
        WebhookQueries.base()
        |> WebhookQueries.for_workspace(workspace.id)
        |> Repo.all()

      assert length(results) == 1
      assert hd(results).id == sub.id
    end
  end

  describe "active/1" do
    test "filters active subscriptions", %{workspace: workspace, user: user} do
      active =
        webhook_subscription_fixture(%{
          workspace_id: workspace.id,
          created_by_id: user.id,
          is_active: true
        })

      _inactive =
        webhook_subscription_fixture(%{
          workspace_id: workspace.id,
          created_by_id: user.id,
          is_active: false
        })

      results =
        WebhookQueries.base()
        |> WebhookQueries.for_workspace(workspace.id)
        |> WebhookQueries.active()
        |> Repo.all()

      assert length(results) == 1
      assert hd(results).id == active.id
    end
  end

  describe "active_for_event/3" do
    test "filters by workspace_id, is_active, and event_type in array", %{
      workspace: workspace,
      user: user
    } do
      matching =
        webhook_subscription_fixture(%{
          workspace_id: workspace.id,
          created_by_id: user.id,
          event_types: ["projects.project_created", "documents.document_created"],
          is_active: true
        })

      _non_matching =
        webhook_subscription_fixture(%{
          workspace_id: workspace.id,
          created_by_id: user.id,
          event_types: ["chat.message_sent"],
          is_active: true
        })

      _inactive =
        webhook_subscription_fixture(%{
          workspace_id: workspace.id,
          created_by_id: user.id,
          event_types: ["projects.project_created"],
          is_active: false
        })

      results =
        WebhookQueries.active_for_event(workspace.id, "projects.project_created")
        |> Repo.all()

      assert length(results) == 1
      assert hd(results).id == matching.id
    end

    test "wildcard — empty event_types matches all events", %{
      workspace: workspace,
      user: user
    } do
      wildcard =
        webhook_subscription_fixture(%{
          workspace_id: workspace.id,
          created_by_id: user.id,
          event_types: [],
          is_active: true
        })

      results =
        WebhookQueries.active_for_event(workspace.id, "any.event")
        |> Repo.all()

      assert length(results) == 1
      assert hd(results).id == wildcard.id
    end
  end

  describe "by_id/2" do
    test "filters by id", %{workspace: workspace, user: user} do
      sub =
        webhook_subscription_fixture(%{
          workspace_id: workspace.id,
          created_by_id: user.id
        })

      result =
        WebhookQueries.base()
        |> WebhookQueries.by_id(sub.id)
        |> Repo.one()

      assert result.id == sub.id
    end

    test "returns nil for non-existent id" do
      result =
        WebhookQueries.base()
        |> WebhookQueries.by_id(Ecto.UUID.generate())
        |> Repo.one()

      assert result == nil
    end
  end
end
