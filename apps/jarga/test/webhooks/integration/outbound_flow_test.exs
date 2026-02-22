defmodule Jarga.Webhooks.Integration.OutboundFlowTest do
  @moduledoc """
  Integration tests for the outbound webhook flow.

  Tests the full stack: create subscription → dispatch delivery → verify HTTP POST.
  Uses Bypass to receive HTTP requests and verify signatures.
  """
  use Jarga.DataCase, async: false

  import Jarga.AccountsFixtures
  import Jarga.WorkspacesFixtures

  alias Jarga.Webhooks
  alias Jarga.Webhooks.Domain.Policies.SignaturePolicy

  setup do
    bypass = Bypass.open()

    owner = user_fixture()
    workspace = workspace_fixture(owner, %{name: "Integration Team"})

    %{bypass: bypass, owner: owner, workspace: workspace}
  end

  describe "outbound webhook full flow" do
    test "creates subscription, dispatches delivery, and receives signed HTTP POST", %{
      bypass: bypass,
      owner: owner,
      workspace: workspace
    } do
      # Step 1: Create subscription pointing to Bypass
      {:ok, subscription} =
        Webhooks.create_subscription(owner, workspace.id, %{
          url: "http://localhost:#{bypass.port}/webhook",
          event_types: ["projects.project_created"]
        })

      assert subscription.url == "http://localhost:#{bypass.port}/webhook"
      assert is_binary(subscription.secret)

      # Step 2: Set up Bypass to receive and verify the webhook
      test_pid = self()

      Bypass.expect_once(bypass, "POST", "/webhook", fn conn ->
        {:ok, body, conn} = Plug.Conn.read_body(conn)
        signature_header = Plug.Conn.get_req_header(conn, "x-webhook-signature") |> List.first()

        send(test_pid, {:webhook_received, body, signature_header})

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, ~s({"ok": true}))
      end)

      # Step 3: Dispatch a delivery
      payload = %{"project_id" => "abc-123", "name" => "My Project"}

      {:ok, delivery} =
        Webhooks.dispatch_delivery(subscription, "projects.project_created", payload)

      assert delivery.status == "success"
      assert delivery.response_code == 200
      assert delivery.attempts == 1

      # Step 4: Verify Bypass received the request with correct signature
      assert_receive {:webhook_received, body, signature_header}, 5000
      parsed_body = Jason.decode!(body)
      assert parsed_body["project_id"] == "abc-123"

      # Verify the HMAC signature matches
      {:ok, hex_sig} = SignaturePolicy.parse_signature_header(signature_header)
      assert SignaturePolicy.verify(body, subscription.secret, hex_sig)
    end

    test "inactive subscription does not trigger delivery", %{
      bypass: bypass,
      owner: owner,
      workspace: workspace
    } do
      # Create inactive subscription
      {:ok, subscription} =
        Webhooks.create_subscription(owner, workspace.id, %{
          url: "http://localhost:#{bypass.port}/webhook",
          event_types: ["projects.project_created"]
        })

      # Deactivate it
      {:ok, inactive_subscription} =
        Webhooks.update_subscription(owner, workspace.id, subscription.id, %{is_active: false})

      assert inactive_subscription.is_active == false

      # Bypass should NOT receive any request
      # Dispatch should return skipped
      result = Webhooks.dispatch_delivery(inactive_subscription, "projects.project_created", %{})

      assert result == {:error, :subscription_inactive}
    end

    test "failed delivery creates record with retry info", %{
      bypass: bypass,
      owner: owner,
      workspace: workspace
    } do
      # Create subscription
      {:ok, subscription} =
        Webhooks.create_subscription(owner, workspace.id, %{
          url: "http://localhost:#{bypass.port}/webhook",
          event_types: ["projects.project_created"]
        })

      # Bypass returns 500
      Bypass.expect_once(bypass, "POST", "/webhook", fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(500, ~s({"error": "Internal Server Error"}))
      end)

      payload = %{"project_id" => "abc-123"}

      {:ok, delivery} =
        Webhooks.dispatch_delivery(subscription, "projects.project_created", payload)

      # First attempt fails, but delivery is pending for retry (not yet exhausted)
      assert delivery.status == "pending"
      assert delivery.response_code == 500
      assert delivery.attempts == 1
      assert delivery.next_retry_at != nil
    end
  end
end
