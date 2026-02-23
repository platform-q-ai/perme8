defmodule WebhooksApi.InboundWebhookApiControllerTest do
  use WebhooksApi.ConnCase, async: true

  import Jarga.AccountsFixtures
  import Jarga.WorkspacesFixtures

  alias Webhooks.Domain.Policies.HmacPolicy
  alias Webhooks.Infrastructure.Schemas.InboundWebhookConfigSchema

  setup do
    owner = user_fixture()
    workspace = workspace_fixture(owner, %{name: "Inbound Test Team"})

    # Create an inbound webhook config with a known secret
    inbound_secret = "test_inbound_secret_#{System.unique_integer([:positive])}"

    {:ok, _config} =
      Webhooks.Repo.insert(
        InboundWebhookConfigSchema.changeset(%InboundWebhookConfigSchema{}, %{
          workspace_id: workspace.id,
          secret: inbound_secret,
          is_active: true
        })
      )

    %{
      owner: owner,
      workspace: workspace,
      inbound_secret: inbound_secret
    }
  end

  describe "POST /api/workspaces/:workspace_slug/webhooks/inbound" do
    test "returns 200 with valid signature", %{
      conn: conn,
      workspace: workspace,
      inbound_secret: inbound_secret
    } do
      payload = Jason.encode!(%{"event" => "test.event", "data" => %{"key" => "value"}})
      signature = HmacPolicy.compute_signature(inbound_secret, payload)

      conn =
        conn
        |> put_req_header("content-type", "application/json")
        |> put_req_header("x-webhook-signature", signature)
        |> post("/api/workspaces/#{workspace.slug}/webhooks/inbound", payload)

      assert conn.status == 200
      response = json_response(conn, 200)
      assert response["data"]["status"] == "received"
    end

    test "returns 401 with invalid signature", %{
      conn: conn,
      workspace: workspace
    } do
      payload = Jason.encode!(%{"event" => "test.event"})

      conn =
        conn
        |> put_req_header("content-type", "application/json")
        |> put_req_header("x-webhook-signature", "invalid_signature")
        |> post("/api/workspaces/#{workspace.slug}/webhooks/inbound", payload)

      assert conn.status == 401
      response = json_response(conn, 401)
      assert response["error"] == "Invalid signature"
    end

    test "returns 401 with missing signature", %{
      conn: conn,
      workspace: workspace
    } do
      payload = Jason.encode!(%{"event" => "test.event"})

      conn =
        conn
        |> put_req_header("content-type", "application/json")
        |> post("/api/workspaces/#{workspace.slug}/webhooks/inbound", payload)

      assert conn.status == 401
      response = json_response(conn, 401)
      assert response["error"] == "Missing signature"
    end

    test "returns 404 for workspace without inbound config", %{conn: conn} do
      # Create a workspace without an inbound config
      other_owner = user_fixture()
      other_workspace = workspace_fixture(other_owner, %{name: "No Config Workspace"})

      payload = Jason.encode!(%{"event" => "test.event"})

      conn =
        conn
        |> put_req_header("content-type", "application/json")
        |> put_req_header("x-webhook-signature", "some_signature")
        |> post("/api/workspaces/#{other_workspace.slug}/webhooks/inbound", payload)

      assert conn.status == 404
      response = json_response(conn, 404)
      assert response["error"] == "Webhook not configured"
    end

    test "returns 404 for non-existent workspace", %{conn: conn} do
      payload = Jason.encode!(%{"event" => "test.event"})

      conn =
        conn
        |> put_req_header("content-type", "application/json")
        |> put_req_header("x-webhook-signature", "some_signature")
        |> post("/api/workspaces/nonexistent-workspace-slug/webhooks/inbound", payload)

      assert conn.status == 404
      response = json_response(conn, 404)
      assert response["error"] == "Workspace not found"
    end
  end
end
