defmodule JargaApi.DeliveryApiControllerTest do
  use JargaApi.ConnCase, async: true

  import Jarga.AccountsFixtures
  import Jarga.WorkspacesFixtures
  import Jarga.WebhookFixtures

  setup do
    owner = user_fixture()
    workspace = workspace_fixture(owner, %{name: "Delivery Team"})

    {:ok, {_api_key, plain_token}} =
      Jarga.Accounts.create_api_key(owner.id, %{
        name: "Delivery API Key",
        workspace_access: [workspace.slug]
      })

    subscription =
      webhook_subscription_fixture(%{
        workspace_id: workspace.id,
        url: "https://example.com/hook"
      })

    # Create a non-admin member user
    member_user = user_fixture()
    _member = add_workspace_member_fixture(workspace.id, member_user, :member)

    {:ok, {_member_api_key, member_token}} =
      Jarga.Accounts.create_api_key(member_user.id, %{
        name: "Member API Key",
        workspace_access: [workspace.slug]
      })

    %{
      owner: owner,
      workspace: workspace,
      plain_token: plain_token,
      subscription: subscription,
      member_token: member_token
    }
  end

  describe "GET /api/workspaces/:workspace_slug/webhooks/:webhook_id/deliveries" do
    test "lists deliveries for a subscription", %{
      conn: conn,
      plain_token: token,
      workspace: workspace,
      subscription: subscription
    } do
      _delivery1 =
        webhook_delivery_fixture(%{
          webhook_subscription_id: subscription.id,
          event_type: "projects.project_created",
          status: "success"
        })

      _delivery2 =
        webhook_delivery_fixture(%{
          webhook_subscription_id: subscription.id,
          event_type: "documents.document_created",
          status: "pending"
        })

      conn =
        conn
        |> put_req_header("authorization", "Bearer #{token}")
        |> get("/api/workspaces/#{workspace.slug}/webhooks/#{subscription.id}/deliveries")

      assert conn.status == 200
      response = json_response(conn, 200)
      assert is_list(response["data"])
      assert length(response["data"]) == 2
    end

    test "returns 403 for non-admin", %{
      conn: conn,
      member_token: token,
      workspace: workspace,
      subscription: subscription
    } do
      conn =
        conn
        |> put_req_header("authorization", "Bearer #{token}")
        |> get("/api/workspaces/#{workspace.slug}/webhooks/#{subscription.id}/deliveries")

      assert conn.status == 403
    end
  end

  describe "GET /api/workspaces/:workspace_slug/webhooks/:webhook_id/deliveries/:id" do
    test "returns delivery details", %{
      conn: conn,
      plain_token: token,
      workspace: workspace,
      subscription: subscription
    } do
      delivery =
        webhook_delivery_fixture(%{
          webhook_subscription_id: subscription.id,
          event_type: "projects.project_created",
          status: "success",
          response_code: 200,
          attempts: 1,
          max_attempts: 5,
          payload: %{"project_id" => "abc"}
        })

      conn =
        conn
        |> put_req_header("authorization", "Bearer #{token}")
        |> get(
          "/api/workspaces/#{workspace.slug}/webhooks/#{subscription.id}/deliveries/#{delivery.id}"
        )

      assert conn.status == 200
      response = json_response(conn, 200)
      assert response["data"]["id"] == delivery.id
      assert response["data"]["event_type"] == "projects.project_created"
      assert response["data"]["status"] == "success"
      assert response["data"]["response_code"] == 200
      assert response["data"]["attempts"] == 1
      assert response["data"]["payload"] == %{"project_id" => "abc"}
    end

    test "returns 404 for non-existent delivery", %{
      conn: conn,
      plain_token: token,
      workspace: workspace,
      subscription: subscription
    } do
      fake_id = Ecto.UUID.generate()

      conn =
        conn
        |> put_req_header("authorization", "Bearer #{token}")
        |> get(
          "/api/workspaces/#{workspace.slug}/webhooks/#{subscription.id}/deliveries/#{fake_id}"
        )

      assert conn.status == 404
      response = json_response(conn, 404)
      assert response["error"] == "Not found"
    end
  end
end
