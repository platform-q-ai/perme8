defmodule JargaApi.Integration.InboundWebhookFlowTest do
  @moduledoc """
  Integration tests for the inbound webhook flow.

  Tests the complete flow: POST to endpoint → signature verification → audit log creation → admin log viewing.
  """
  use JargaApi.ConnCase, async: false

  import Jarga.AccountsFixtures
  import Jarga.WorkspacesFixtures
  import Jarga.WebhookFixtures

  setup do
    owner = user_fixture()
    workspace = workspace_fixture(owner, %{name: "Inbound Integration Team"})

    {:ok, {_api_key, plain_token}} =
      Jarga.Accounts.create_api_key(owner.id, %{
        name: "Integration API Key",
        workspace_access: [workspace.slug]
      })

    # Store the inbound webhook secret in the database (server-side)
    config = inbound_webhook_config_fixture(%{workspace_id: workspace.id})

    %{
      owner: owner,
      workspace: workspace,
      plain_token: plain_token,
      workspace_secret: config.inbound_secret
    }
  end

  describe "inbound webhook full flow" do
    test "POST with valid signature → 200, then admin can view audit log", %{
      conn: conn,
      workspace: workspace,
      plain_token: token,
      workspace_secret: secret
    } do
      # Step 1: Send inbound webhook with valid signature (raw body is used for HMAC)
      raw_body = Jason.encode!(%{"event_type" => "payment.received", "amount" => 100})

      signature =
        "sha256=" <>
          (:crypto.mac(:hmac, :sha256, secret, raw_body) |> Base.encode16(case: :lower))

      receive_conn =
        build_conn()
        |> put_req_header("content-type", "application/json")
        |> put_req_header("x-webhook-signature", signature)
        |> post("/api/workspaces/#{workspace.slug}/webhooks/inbound", raw_body)

      assert receive_conn.status == 200
      response = json_response(receive_conn, 200)
      assert response["data"]["status"] == "accepted"

      # Step 2: Admin views audit logs
      logs_conn =
        conn
        |> put_req_header("authorization", "Bearer #{token}")
        |> get("/api/workspaces/#{workspace.slug}/webhooks/inbound/logs")

      assert logs_conn.status == 200
      logs_response = json_response(logs_conn, 200)
      assert length(logs_response["data"]) == 1

      log = hd(logs_response["data"])
      assert log["event_type"] == "payment.received"
      assert log["signature_valid"] == true
    end

    test "POST with invalid signature → 401, no audit log created", %{
      conn: conn,
      workspace: workspace,
      plain_token: token
    } do
      raw_body = Jason.encode!(%{"event_type" => "payment.received"})
      bad_signature = "sha256=0000000000000000000000000000000000000000000000000000000000000000"

      receive_conn =
        build_conn()
        |> put_req_header("content-type", "application/json")
        |> put_req_header("x-webhook-signature", bad_signature)
        |> post("/api/workspaces/#{workspace.slug}/webhooks/inbound", raw_body)

      assert receive_conn.status == 401

      # Verify no audit log was created
      logs_conn =
        conn
        |> put_req_header("authorization", "Bearer #{token}")
        |> get("/api/workspaces/#{workspace.slug}/webhooks/inbound/logs")

      assert logs_conn.status == 200
      logs_response = json_response(logs_conn, 200)
      assert logs_response["data"] == []
    end
  end
end
