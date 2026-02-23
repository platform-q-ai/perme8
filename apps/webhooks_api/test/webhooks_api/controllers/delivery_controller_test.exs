defmodule WebhooksApi.DeliveryControllerTest do
  use WebhooksApi.ConnCase, async: true

  import Jarga.AccountsFixtures
  import Jarga.WorkspacesFixtures

  alias Webhooks.Infrastructure.Schemas.DeliverySchema

  setup do
    owner = user_fixture()
    workspace = workspace_fixture(owner, %{name: "Delivery Test Team"})

    member_user = user_fixture()
    add_workspace_member_fixture(workspace.id, member_user, :member)

    {:ok, {_owner_api_key, owner_token}} =
      Identity.create_api_key(owner.id, %{
        name: "Owner Key",
        workspace_access: [workspace.slug]
      })

    {:ok, {_member_api_key, member_token}} =
      Identity.create_api_key(member_user.id, %{
        name: "Member Key",
        workspace_access: [workspace.slug]
      })

    # Create a subscription for delivery tests
    api_key = conn_api_key(owner_token)

    {:ok, subscription} =
      Webhooks.create_subscription(owner, api_key, workspace.slug, %{
        "url" => "https://example.com/hook",
        "event_types" => ["project.created"]
      })

    %{
      owner: owner,
      workspace: workspace,
      owner_token: owner_token,
      member_token: member_token,
      subscription: subscription
    }
  end

  describe "GET /api/workspaces/:workspace_slug/webhooks/:subscription_id/deliveries" do
    test "returns 200 with list of deliveries", %{
      conn: conn,
      owner_token: owner_token,
      workspace: workspace,
      subscription: subscription
    } do
      # Insert delivery records directly via schema
      {:ok, _delivery} =
        WebhooksApi.Repo.insert(
          DeliverySchema.changeset(%DeliverySchema{}, %{
            subscription_id: subscription.id,
            event_type: "project.created",
            payload: %{"project_id" => "123"},
            status: "success",
            response_code: 200
          })
        )

      conn =
        conn
        |> put_req_header("authorization", "Bearer #{owner_token}")
        |> get("/api/workspaces/#{workspace.slug}/webhooks/#{subscription.id}/deliveries")

      assert conn.status == 200
      response = json_response(conn, 200)
      assert is_list(response["data"])
      assert length(response["data"]) == 1

      delivery = hd(response["data"])
      assert delivery["event_type"] == "project.created"
      assert delivery["status"] == "success"
      assert delivery["response_code"] == 200
    end

    test "returns 403 for member role user", %{
      conn: conn,
      member_token: member_token,
      workspace: workspace,
      subscription: subscription
    } do
      conn =
        conn
        |> put_req_header("authorization", "Bearer #{member_token}")
        |> get("/api/workspaces/#{workspace.slug}/webhooks/#{subscription.id}/deliveries")

      assert conn.status == 403
    end

    test "returns 404 for non-existent subscription", %{
      conn: conn,
      owner_token: owner_token,
      workspace: workspace
    } do
      fake_sub_id = Ecto.UUID.generate()

      conn =
        conn
        |> put_req_header("authorization", "Bearer #{owner_token}")
        |> get("/api/workspaces/#{workspace.slug}/webhooks/#{fake_sub_id}/deliveries")

      assert conn.status == 404
    end
  end

  describe "GET /api/workspaces/:workspace_slug/webhooks/:subscription_id/deliveries/:id" do
    test "returns 200 with full delivery details", %{
      conn: conn,
      owner_token: owner_token,
      workspace: workspace,
      subscription: subscription
    } do
      {:ok, delivery_schema} =
        WebhooksApi.Repo.insert(
          DeliverySchema.changeset(%DeliverySchema{}, %{
            subscription_id: subscription.id,
            event_type: "project.created",
            payload: %{"project_id" => "456"},
            status: "success",
            response_code: 200,
            response_body: "OK",
            attempts: 1
          })
        )

      conn =
        conn
        |> put_req_header("authorization", "Bearer #{owner_token}")
        |> get(
          "/api/workspaces/#{workspace.slug}/webhooks/#{subscription.id}/deliveries/#{delivery_schema.id}"
        )

      assert conn.status == 200
      response = json_response(conn, 200)
      assert response["data"]["id"] == delivery_schema.id
      assert response["data"]["subscription_id"] == subscription.id
      assert response["data"]["event_type"] == "project.created"
      assert response["data"]["payload"] == %{"project_id" => "456"}
      assert response["data"]["status"] == "success"
      assert response["data"]["response_code"] == 200
      assert response["data"]["response_body"] == "OK"
      assert response["data"]["attempts"] == 1
    end

    test "returns 404 for non-existent delivery", %{
      conn: conn,
      owner_token: owner_token,
      workspace: workspace,
      subscription: subscription
    } do
      fake_id = Ecto.UUID.generate()

      conn =
        conn
        |> put_req_header("authorization", "Bearer #{owner_token}")
        |> get(
          "/api/workspaces/#{workspace.slug}/webhooks/#{subscription.id}/deliveries/#{fake_id}"
        )

      assert conn.status == 404
      response = json_response(conn, 404)
      assert response["error"] == "Delivery not found"
    end
  end

  defp conn_api_key(plain_token) do
    {:ok, api_key} = Identity.verify_api_key(plain_token)
    api_key
  end
end
