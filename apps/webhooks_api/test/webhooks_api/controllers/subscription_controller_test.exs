defmodule WebhooksApi.SubscriptionControllerTest do
  use WebhooksApi.ConnCase, async: true

  import Jarga.AccountsFixtures
  import Jarga.WorkspacesFixtures

  setup do
    owner = user_fixture()
    workspace = workspace_fixture(owner, %{name: "Webhook Team"})

    # Create a member user with "member" role (not admin/owner)
    member_user = user_fixture()
    add_workspace_member_fixture(workspace.id, member_user, :member)

    # Create an admin user
    admin_user = user_fixture()
    add_workspace_member_fixture(workspace.id, admin_user, :admin)

    # Create API key for owner with workspace access
    {:ok, {_owner_api_key, owner_token}} =
      Identity.create_api_key(owner.id, %{
        name: "Owner Key",
        workspace_access: [workspace.slug]
      })

    # Create API key for member with workspace access
    {:ok, {_member_api_key, member_token}} =
      Identity.create_api_key(member_user.id, %{
        name: "Member Key",
        workspace_access: [workspace.slug]
      })

    # Create API key for admin with workspace access
    {:ok, {_admin_api_key, admin_token}} =
      Identity.create_api_key(admin_user.id, %{
        name: "Admin Key",
        workspace_access: [workspace.slug]
      })

    %{
      owner: owner,
      workspace: workspace,
      member_user: member_user,
      admin_user: admin_user,
      owner_token: owner_token,
      member_token: member_token,
      admin_token: admin_token
    }
  end

  describe "POST /api/workspaces/:workspace_slug/webhooks" do
    test "returns 201 with subscription including secret on success", %{
      conn: conn,
      owner_token: owner_token,
      workspace: workspace,
      owner: owner
    } do
      conn =
        conn
        |> put_req_header("authorization", "Bearer #{owner_token}")
        |> post("/api/workspaces/#{workspace.slug}/webhooks", %{
          "url" => "https://example.com/webhook",
          "event_types" => ["project.created", "document.updated"]
        })

      assert conn.status == 201
      response = json_response(conn, 201)

      assert response["data"]["url"] == "https://example.com/webhook"
      assert response["data"]["event_types"] == ["project.created", "document.updated"]
      assert response["data"]["is_active"] == true
      assert response["data"]["workspace_id"] == workspace.id
      assert response["data"]["created_by_id"] == owner.id

      # Secret is included on creation
      assert is_binary(response["data"]["secret"])
      assert byte_size(response["data"]["secret"]) > 0
    end

    test "returns 201 for admin user", %{
      conn: conn,
      admin_token: admin_token,
      workspace: workspace
    } do
      conn =
        conn
        |> put_req_header("authorization", "Bearer #{admin_token}")
        |> post("/api/workspaces/#{workspace.slug}/webhooks", %{
          "url" => "https://example.com/hook",
          "event_types" => ["project.created"]
        })

      assert conn.status == 201
    end

    test "returns 422 for invalid data (missing url)", %{
      conn: conn,
      owner_token: owner_token,
      workspace: workspace
    } do
      conn =
        conn
        |> put_req_header("authorization", "Bearer #{owner_token}")
        |> post("/api/workspaces/#{workspace.slug}/webhooks", %{
          "event_types" => ["project.created"]
        })

      assert conn.status == 422
      response = json_response(conn, 422)
      assert response["errors"]["url"]
    end

    test "returns 403 for member role user", %{
      conn: conn,
      member_token: member_token,
      workspace: workspace
    } do
      conn =
        conn
        |> put_req_header("authorization", "Bearer #{member_token}")
        |> post("/api/workspaces/#{workspace.slug}/webhooks", %{
          "url" => "https://example.com/webhook",
          "event_types" => ["project.created"]
        })

      assert conn.status == 403
      response = json_response(conn, 403)
      assert response["error"] == "Insufficient permissions"
    end

    test "returns 401 when no authorization header", %{conn: conn, workspace: workspace} do
      conn =
        post(conn, "/api/workspaces/#{workspace.slug}/webhooks", %{
          "url" => "https://example.com/webhook",
          "event_types" => ["project.created"]
        })

      assert conn.status == 401
      response = json_response(conn, 401)
      assert response["error"] == "Invalid or revoked API key"
    end

    test "returns 401 when invalid bearer token", %{conn: conn, workspace: workspace} do
      conn =
        conn
        |> put_req_header("authorization", "Bearer invalid-token-xxx")
        |> post("/api/workspaces/#{workspace.slug}/webhooks", %{
          "url" => "https://example.com/webhook",
          "event_types" => ["project.created"]
        })

      assert conn.status == 401
    end
  end

  describe "GET /api/workspaces/:workspace_slug/webhooks" do
    test "returns 200 with list of subscriptions (no secrets)", %{
      conn: conn,
      owner_token: owner_token,
      workspace: workspace,
      owner: owner
    } do
      # Create two subscriptions
      api_key = conn_api_key(owner_token)

      {:ok, _sub1} =
        Webhooks.create_subscription(owner, api_key, workspace.slug, %{
          "url" => "https://example.com/hook1",
          "event_types" => ["project.created"]
        })

      {:ok, _sub2} =
        Webhooks.create_subscription(owner, api_key, workspace.slug, %{
          "url" => "https://example.com/hook2",
          "event_types" => ["document.updated"]
        })

      conn =
        conn
        |> put_req_header("authorization", "Bearer #{owner_token}")
        |> get("/api/workspaces/#{workspace.slug}/webhooks")

      assert conn.status == 200
      response = json_response(conn, 200)
      assert length(response["data"]) == 2

      # Secrets should NOT be included in list response
      Enum.each(response["data"], fn sub ->
        refute Map.has_key?(sub, "secret")
      end)
    end

    test "returns 403 for member role user", %{
      conn: conn,
      member_token: member_token,
      workspace: workspace
    } do
      conn =
        conn
        |> put_req_header("authorization", "Bearer #{member_token}")
        |> get("/api/workspaces/#{workspace.slug}/webhooks")

      assert conn.status == 403
    end
  end

  describe "GET /api/workspaces/:workspace_slug/webhooks/:id" do
    test "returns 200 with subscription (no secret)", %{
      conn: conn,
      owner_token: owner_token,
      workspace: workspace,
      owner: owner
    } do
      api_key = conn_api_key(owner_token)

      {:ok, subscription} =
        Webhooks.create_subscription(owner, api_key, workspace.slug, %{
          "url" => "https://example.com/hook",
          "event_types" => ["project.created"]
        })

      conn =
        conn
        |> put_req_header("authorization", "Bearer #{owner_token}")
        |> get("/api/workspaces/#{workspace.slug}/webhooks/#{subscription.id}")

      assert conn.status == 200
      response = json_response(conn, 200)
      assert response["data"]["id"] == subscription.id
      assert response["data"]["url"] == "https://example.com/hook"

      # Secret should NOT be in show response
      refute Map.has_key?(response["data"], "secret")
    end

    test "returns 404 for non-existent subscription", %{
      conn: conn,
      owner_token: owner_token,
      workspace: workspace
    } do
      non_existent_id = Ecto.UUID.generate()

      conn =
        conn
        |> put_req_header("authorization", "Bearer #{owner_token}")
        |> get("/api/workspaces/#{workspace.slug}/webhooks/#{non_existent_id}")

      assert conn.status == 404
      response = json_response(conn, 404)
      assert response["error"] == "Subscription not found"
    end

    test "returns 403 for member role user", %{
      conn: conn,
      owner_token: owner_token,
      member_token: member_token,
      workspace: workspace,
      owner: owner
    } do
      api_key = conn_api_key(owner_token)

      {:ok, subscription} =
        Webhooks.create_subscription(owner, api_key, workspace.slug, %{
          "url" => "https://example.com/hook",
          "event_types" => ["project.created"]
        })

      conn =
        conn
        |> put_req_header("authorization", "Bearer #{member_token}")
        |> get("/api/workspaces/#{workspace.slug}/webhooks/#{subscription.id}")

      assert conn.status == 403
    end
  end

  describe "PATCH /api/workspaces/:workspace_slug/webhooks/:id" do
    test "returns 200 with updated subscription", %{
      conn: conn,
      owner_token: owner_token,
      workspace: workspace,
      owner: owner
    } do
      api_key = conn_api_key(owner_token)

      {:ok, subscription} =
        Webhooks.create_subscription(owner, api_key, workspace.slug, %{
          "url" => "https://example.com/hook",
          "event_types" => ["project.created"]
        })

      conn =
        conn
        |> put_req_header("authorization", "Bearer #{owner_token}")
        |> patch("/api/workspaces/#{workspace.slug}/webhooks/#{subscription.id}", %{
          "url" => "https://example.com/updated-hook",
          "is_active" => false
        })

      assert conn.status == 200
      response = json_response(conn, 200)
      assert response["data"]["url"] == "https://example.com/updated-hook"
      assert response["data"]["is_active"] == false

      # No secret on update
      refute Map.has_key?(response["data"], "secret")
    end

    test "returns 404 for non-existent subscription", %{
      conn: conn,
      owner_token: owner_token,
      workspace: workspace
    } do
      non_existent_id = Ecto.UUID.generate()

      conn =
        conn
        |> put_req_header("authorization", "Bearer #{owner_token}")
        |> patch("/api/workspaces/#{workspace.slug}/webhooks/#{non_existent_id}", %{
          "url" => "https://example.com/updated-hook"
        })

      assert conn.status == 404
    end

    test "returns 403 for member role user", %{
      conn: conn,
      owner_token: owner_token,
      member_token: member_token,
      workspace: workspace,
      owner: owner
    } do
      api_key = conn_api_key(owner_token)

      {:ok, subscription} =
        Webhooks.create_subscription(owner, api_key, workspace.slug, %{
          "url" => "https://example.com/hook",
          "event_types" => ["project.created"]
        })

      conn =
        conn
        |> put_req_header("authorization", "Bearer #{member_token}")
        |> patch("/api/workspaces/#{workspace.slug}/webhooks/#{subscription.id}", %{
          "url" => "https://example.com/updated-hook"
        })

      assert conn.status == 403
    end
  end

  describe "DELETE /api/workspaces/:workspace_slug/webhooks/:id" do
    test "returns 200 on successful deletion", %{
      conn: conn,
      owner_token: owner_token,
      workspace: workspace,
      owner: owner
    } do
      api_key = conn_api_key(owner_token)

      {:ok, subscription} =
        Webhooks.create_subscription(owner, api_key, workspace.slug, %{
          "url" => "https://example.com/hook",
          "event_types" => ["project.created"]
        })

      conn =
        conn
        |> put_req_header("authorization", "Bearer #{owner_token}")
        |> delete("/api/workspaces/#{workspace.slug}/webhooks/#{subscription.id}")

      assert conn.status == 200
      response = json_response(conn, 200)
      assert response["data"]["deleted"] == true
    end

    test "returns 404 for non-existent subscription", %{
      conn: conn,
      owner_token: owner_token,
      workspace: workspace
    } do
      non_existent_id = Ecto.UUID.generate()

      conn =
        conn
        |> put_req_header("authorization", "Bearer #{owner_token}")
        |> delete("/api/workspaces/#{workspace.slug}/webhooks/#{non_existent_id}")

      assert conn.status == 404
    end

    test "returns 403 for member role user", %{
      conn: conn,
      owner_token: owner_token,
      member_token: member_token,
      workspace: workspace,
      owner: owner
    } do
      api_key = conn_api_key(owner_token)

      {:ok, subscription} =
        Webhooks.create_subscription(owner, api_key, workspace.slug, %{
          "url" => "https://example.com/hook",
          "event_types" => ["project.created"]
        })

      conn =
        conn
        |> put_req_header("authorization", "Bearer #{member_token}")
        |> delete("/api/workspaces/#{workspace.slug}/webhooks/#{subscription.id}")

      assert conn.status == 403
    end
  end

  describe "API key scope checking" do
    test "returns 403 when workspace not in API key scope", %{
      conn: conn,
      owner: owner
    } do
      # Create another workspace the owner belongs to
      other_workspace = workspace_fixture(owner, %{name: "Other Workspace"})

      # Create API key WITHOUT the other workspace in scope (bypass validation)
      {_api_key, scoped_token} =
        api_key_fixture_without_validation(owner.id, %{
          name: "Scoped Key",
          workspace_access: ["some-other-slug"]
        })

      conn =
        conn
        |> put_req_header("authorization", "Bearer #{scoped_token}")
        |> get("/api/workspaces/#{other_workspace.slug}/webhooks")

      assert conn.status == 403
      response = json_response(conn, 403)
      assert response["error"] == "Insufficient permissions"
    end
  end

  # Helper to get the api_key entity from a plain token
  defp conn_api_key(plain_token) do
    {:ok, api_key} = Identity.verify_api_key(plain_token)
    api_key
  end
end
