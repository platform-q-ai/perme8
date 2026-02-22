defmodule Jarga.Webhooks.Integration.RetryFlowTest do
  @moduledoc """
  Integration tests for the webhook delivery retry flow.

  Tests the retry mechanism: failed delivery → retry → verify status changes.
  Uses Bypass to simulate HTTP endpoints with configurable responses.
  """
  use Jarga.DataCase, async: false

  import Jarga.AccountsFixtures
  import Jarga.WorkspacesFixtures

  alias Jarga.Webhooks

  setup do
    bypass = Bypass.open()

    owner = user_fixture()
    workspace = workspace_fixture(owner, %{name: "Retry Team"})

    # Create subscription
    {:ok, subscription} =
      Webhooks.create_subscription(owner, workspace.id, %{
        url: "http://localhost:#{bypass.port}/webhook",
        event_types: ["projects.project_created"]
      })

    %{bypass: bypass, owner: owner, workspace: workspace, subscription: subscription}
  end

  describe "retry flow" do
    test "failed delivery → retry succeeds → status updated to success", %{
      bypass: bypass,
      subscription: subscription
    } do
      # First dispatch fails with 500
      Bypass.expect_once(bypass, "POST", "/webhook", fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(500, ~s({"error": "server error"}))
      end)

      {:ok, failed_delivery} =
        Webhooks.dispatch_delivery(subscription, "projects.project_created", %{"id" => "1"})

      assert failed_delivery.status == "pending"
      assert failed_delivery.attempts == 1

      # Retry succeeds with 200
      Bypass.expect_once(bypass, "POST", "/webhook", fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, ~s({"ok": true}))
      end)

      {:ok, retried_delivery} = Webhooks.retry_delivery(failed_delivery, subscription)

      assert retried_delivery.status == "success"
      assert retried_delivery.response_code == 200
      assert retried_delivery.attempts == 2
      assert retried_delivery.next_retry_at == nil
    end

    test "failed delivery → retry fails → attempts incremented, next_retry_at set", %{
      bypass: bypass,
      subscription: subscription
    } do
      # First dispatch fails
      Bypass.expect_once(bypass, "POST", "/webhook", fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(503, ~s({"error": "service unavailable"}))
      end)

      {:ok, failed_delivery} =
        Webhooks.dispatch_delivery(subscription, "projects.project_created", %{"id" => "2"})

      assert failed_delivery.status == "pending"
      assert failed_delivery.attempts == 1

      # Retry also fails
      Bypass.expect_once(bypass, "POST", "/webhook", fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(503, ~s({"error": "still down"}))
      end)

      {:ok, retried_delivery} = Webhooks.retry_delivery(failed_delivery, subscription)

      assert retried_delivery.status == "pending"
      assert retried_delivery.attempts == 2
      assert retried_delivery.next_retry_at != nil
    end

    test "max retries exhausted → status failed, no next_retry_at", %{
      bypass: bypass,
      subscription: subscription
    } do
      # Dispatch with max_attempts = 1 to exhaust immediately
      Bypass.expect_once(bypass, "POST", "/webhook", fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(500, ~s({"error": "server error"}))
      end)

      {:ok, failed_delivery} =
        Webhooks.dispatch_delivery(
          subscription,
          "projects.project_created",
          %{"id" => "3"},
          max_attempts: 1
        )

      # With max_attempts: 1 and 1 attempt, retries are exhausted → failed
      assert failed_delivery.status == "failed"
      assert failed_delivery.attempts == 1
      assert failed_delivery.next_retry_at == nil
    end
  end
end
