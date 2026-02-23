defmodule WebhooksApi.InboundLogControllerTest do
  use WebhooksApi.ConnCase, async: true

  import Jarga.AccountsFixtures
  import Jarga.WorkspacesFixtures

  alias Webhooks.Infrastructure.Schemas.InboundLogSchema

  setup do
    owner = user_fixture()
    workspace = workspace_fixture(owner, %{name: "Inbound Log Team"})

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

    %{
      owner: owner,
      workspace: workspace,
      owner_token: owner_token,
      member_token: member_token
    }
  end

  describe "GET /api/workspaces/:workspace_slug/webhooks/inbound/logs" do
    test "returns 200 with list of inbound logs", %{
      conn: conn,
      owner_token: owner_token,
      workspace: workspace
    } do
      now = DateTime.utc_now() |> DateTime.truncate(:second)

      # Insert inbound log records directly
      {:ok, _log1} =
        WebhooksApi.Repo.insert(
          InboundLogSchema.changeset(%InboundLogSchema{}, %{
            workspace_id: workspace.id,
            event_type: "payment.completed",
            payload: %{"amount" => 100},
            source_ip: "192.168.1.1",
            signature_valid: true,
            received_at: now
          })
        )

      {:ok, _log2} =
        WebhooksApi.Repo.insert(
          InboundLogSchema.changeset(%InboundLogSchema{}, %{
            workspace_id: workspace.id,
            event_type: "payment.failed",
            payload: %{"error" => "declined"},
            source_ip: "10.0.0.1",
            signature_valid: false,
            received_at: now
          })
        )

      conn =
        conn
        |> put_req_header("authorization", "Bearer #{owner_token}")
        |> get("/api/workspaces/#{workspace.slug}/webhooks/inbound/logs")

      assert conn.status == 200
      response = json_response(conn, 200)
      assert is_list(response["data"])
      assert length(response["data"]) == 2

      # Check fields are present
      log = hd(response["data"])
      assert Map.has_key?(log, "id")
      assert Map.has_key?(log, "event_type")
      assert Map.has_key?(log, "payload")
      assert Map.has_key?(log, "signature_valid")
      assert Map.has_key?(log, "source_ip")
      assert Map.has_key?(log, "received_at")
    end

    test "returns 403 for member role user", %{
      conn: conn,
      member_token: member_token,
      workspace: workspace
    } do
      conn =
        conn
        |> put_req_header("authorization", "Bearer #{member_token}")
        |> get("/api/workspaces/#{workspace.slug}/webhooks/inbound/logs")

      assert conn.status == 403
      response = json_response(conn, 403)
      assert response["error"] == "Insufficient permissions"
    end

    test "returns 401 when not authenticated", %{conn: conn, workspace: workspace} do
      conn = get(conn, "/api/workspaces/#{workspace.slug}/webhooks/inbound/logs")

      assert conn.status == 401
    end
  end
end
