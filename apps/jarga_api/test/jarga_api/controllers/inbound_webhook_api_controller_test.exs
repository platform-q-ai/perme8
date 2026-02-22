defmodule JargaApi.InboundWebhookApiControllerTest do
  use JargaApi.ConnCase, async: true

  import Jarga.AccountsFixtures
  import Jarga.WorkspacesFixtures
  import Jarga.WebhookFixtures

  setup do
    owner = user_fixture()
    workspace = workspace_fixture(owner, %{name: "Inbound Team"})

    {:ok, {_api_key, plain_token}} =
      Jarga.Accounts.create_api_key(owner.id, %{
        name: "Inbound API Key",
        workspace_access: [workspace.slug]
      })

    # Create a non-admin member user
    member_user = user_fixture()
    _member = add_workspace_member_fixture(workspace.id, member_user, :member)

    {:ok, {_member_api_key, member_token}} =
      Jarga.Accounts.create_api_key(member_user.id, %{
        name: "Member API Key",
        workspace_access: [workspace.slug]
      })

    # Generate a workspace-level webhook secret for inbound signature verification
    workspace_secret = :crypto.strong_rand_bytes(32) |> Base.url_encode64(padding: false)

    %{
      owner: owner,
      workspace: workspace,
      plain_token: plain_token,
      member_token: member_token,
      workspace_secret: workspace_secret
    }
  end

  describe "POST /api/workspaces/:workspace_slug/webhooks/inbound" do
    test "accepts webhook with valid signature", %{
      conn: conn,
      workspace: workspace,
      workspace_secret: secret
    } do
      # Build payload and encode it deterministically — the controller will
      # re-encode the parsed body with Jason, so we use Jason's output for the HMAC
      payload = %{"event" => "payment.received", "data" => %{"amount" => 100}}
      encoded_body = Jason.encode!(payload)

      signature =
        "sha256=" <>
          (:crypto.mac(:hmac, :sha256, secret, encoded_body) |> Base.encode16(case: :lower))

      conn =
        conn
        |> put_req_header("content-type", "application/json")
        |> put_req_header("x-webhook-signature", signature)
        |> put_req_header("x-webhook-secret", secret)
        |> post("/api/workspaces/#{workspace.slug}/webhooks/inbound", payload)

      assert conn.status == 200
      response = json_response(conn, 200)
      assert response["data"]["status"] == "accepted"
    end

    test "returns 401 when signature is missing", %{
      conn: conn,
      workspace: workspace
    } do
      body = ~s({"event":"payment.received"})

      conn =
        conn
        |> put_req_header("content-type", "application/json")
        |> post("/api/workspaces/#{workspace.slug}/webhooks/inbound", body)

      assert conn.status == 401
    end

    test "returns 401 when signature is invalid", %{
      conn: conn,
      workspace: workspace,
      workspace_secret: secret
    } do
      body = ~s({"event":"payment.received"})
      bad_signature = "sha256=0000000000000000000000000000000000000000000000000000000000000000"

      conn =
        conn
        |> put_req_header("content-type", "application/json")
        |> put_req_header("x-webhook-signature", bad_signature)
        |> put_req_header("x-webhook-secret", secret)
        |> post("/api/workspaces/#{workspace.slug}/webhooks/inbound", body)

      assert conn.status == 401
      response = json_response(conn, 401)
      assert response["error"] =~ "signature"
    end

    test "returns 400 for malformed JSON", %{
      conn: conn,
      workspace: workspace,
      workspace_secret: secret
    } do
      # Malformed JSON with content-type: application/json will be rejected by
      # Plug.Parsers before reaching our controller, resulting in a 400 error
      body = "this is not json"

      signature =
        "sha256=" <> (:crypto.mac(:hmac, :sha256, secret, body) |> Base.encode16(case: :lower))

      assert_raise Plug.Parsers.ParseError, fn ->
        conn
        |> put_req_header("content-type", "application/json")
        |> put_req_header("x-webhook-signature", signature)
        |> put_req_header("x-webhook-secret", secret)
        |> post("/api/workspaces/#{workspace.slug}/webhooks/inbound", body)
      end
    end
  end

  describe "GET /api/workspaces/:workspace_slug/webhooks/inbound/logs" do
    test "lists inbound webhook audit logs for admin", %{
      conn: conn,
      plain_token: token,
      workspace: workspace
    } do
      # Create some inbound webhook records
      _log1 =
        inbound_webhook_fixture(%{
          workspace_id: workspace.id,
          event_type: "payment.received",
          signature_valid: true
        })

      _log2 =
        inbound_webhook_fixture(%{
          workspace_id: workspace.id,
          event_type: "order.created",
          signature_valid: false
        })

      conn =
        conn
        |> put_req_header("authorization", "Bearer #{token}")
        |> get("/api/workspaces/#{workspace.slug}/webhooks/inbound/logs")

      assert conn.status == 200
      response = json_response(conn, 200)
      assert is_list(response["data"])
      assert length(response["data"]) == 2

      # Verify fields are present
      log = hd(response["data"])
      assert Map.has_key?(log, "event_type")
      assert Map.has_key?(log, "payload")
      assert Map.has_key?(log, "signature_valid")
      assert Map.has_key?(log, "received_at")
    end

    test "returns 403 for non-admin", %{
      conn: conn,
      member_token: token,
      workspace: workspace
    } do
      conn =
        conn
        |> put_req_header("authorization", "Bearer #{token}")
        |> get("/api/workspaces/#{workspace.slug}/webhooks/inbound/logs")

      assert conn.status == 403
    end
  end
end
