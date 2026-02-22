defmodule JargaApi.WebhookApiControllerTest do
  use JargaApi.ConnCase, async: true

  import Jarga.AccountsFixtures
  import Jarga.WorkspacesFixtures
  import Jarga.WebhookFixtures

  setup do
    # Create owner user with workspace
    owner = user_fixture()
    workspace = workspace_fixture(owner, %{name: "Webhook Team"})

    # Create API key with access to the workspace
    {:ok, {api_key, plain_token}} =
      Jarga.Accounts.create_api_key(owner.id, %{
        name: "Webhook API Key",
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

    %{
      owner: owner,
      workspace: workspace,
      api_key: api_key,
      plain_token: plain_token,
      member_user: member_user,
      member_token: member_token
    }
  end

  describe "POST /api/workspaces/:workspace_slug/webhooks" do
    test "creates subscription with valid attrs and returns secret only on creation", %{
      conn: conn,
      plain_token: token,
      workspace: workspace
    } do
      attrs = %{
        "url" => "https://example.com/webhook",
        "event_types" => ["projects.project_created", "documents.document_created"]
      }

      conn =
        conn
        |> put_req_header("authorization", "Bearer #{token}")
        |> post("/api/workspaces/#{workspace.slug}/webhooks", attrs)

      assert conn.status == 201
      response = json_response(conn, 201)
      assert response["data"]["url"] == "https://example.com/webhook"

      assert response["data"]["event_types"] == [
               "projects.project_created",
               "documents.document_created"
             ]

      assert response["data"]["is_active"] == true
      assert is_binary(response["data"]["id"])
      # Secret should be returned on creation
      assert is_binary(response["data"]["secret"])
      assert String.length(response["data"]["secret"]) >= 32
    end

    test "returns 422 when URL is missing", %{
      conn: conn,
      plain_token: token,
      workspace: workspace
    } do
      attrs = %{"event_types" => ["projects.project_created"]}

      conn =
        conn
        |> put_req_header("authorization", "Bearer #{token}")
        |> post("/api/workspaces/#{workspace.slug}/webhooks", attrs)

      assert conn.status == 422
      response = json_response(conn, 422)
      assert response["errors"]["url"]
    end

    test "returns 403 when non-admin user", %{
      conn: conn,
      member_token: token,
      workspace: workspace
    } do
      attrs = %{
        "url" => "https://example.com/webhook",
        "event_types" => ["projects.project_created"]
      }

      conn =
        conn
        |> put_req_header("authorization", "Bearer #{token}")
        |> post("/api/workspaces/#{workspace.slug}/webhooks", attrs)

      assert conn.status == 403
      response = json_response(conn, 403)
      assert response["error"] == "Insufficient permissions"
    end

    test "returns 401 when unauthenticated", %{conn: conn, workspace: workspace} do
      attrs = %{"url" => "https://example.com/webhook"}

      conn = post(conn, "/api/workspaces/#{workspace.slug}/webhooks", attrs)

      assert conn.status == 401
    end
  end

  describe "GET /api/workspaces/:workspace_slug/webhooks" do
    test "lists subscriptions for workspace without exposing secrets", %{
      conn: conn,
      plain_token: token,
      workspace: workspace
    } do
      # Create a couple of subscriptions
      _sub1 =
        webhook_subscription_fixture(%{
          workspace_id: workspace.id,
          url: "https://example.com/hook1",
          event_types: ["projects.project_created"]
        })

      _sub2 =
        webhook_subscription_fixture(%{
          workspace_id: workspace.id,
          url: "https://example.com/hook2",
          event_types: ["documents.document_created"]
        })

      conn =
        conn
        |> put_req_header("authorization", "Bearer #{token}")
        |> get("/api/workspaces/#{workspace.slug}/webhooks")

      assert conn.status == 200
      response = json_response(conn, 200)
      assert is_list(response["data"])
      assert length(response["data"]) == 2

      # Secrets should NOT be exposed in list responses
      Enum.each(response["data"], fn sub ->
        refute Map.has_key?(sub, "secret")
      end)
    end

    test "returns 403 for non-admin", %{
      conn: conn,
      member_token: token,
      workspace: workspace
    } do
      conn =
        conn
        |> put_req_header("authorization", "Bearer #{token}")
        |> get("/api/workspaces/#{workspace.slug}/webhooks")

      assert conn.status == 403
    end
  end

  describe "GET /api/workspaces/:workspace_slug/webhooks/:id" do
    test "returns subscription by ID without exposing secret", %{
      conn: conn,
      plain_token: token,
      workspace: workspace
    } do
      sub =
        webhook_subscription_fixture(%{
          workspace_id: workspace.id,
          url: "https://example.com/hook",
          event_types: ["projects.project_created"]
        })

      conn =
        conn
        |> put_req_header("authorization", "Bearer #{token}")
        |> get("/api/workspaces/#{workspace.slug}/webhooks/#{sub.id}")

      assert conn.status == 200
      response = json_response(conn, 200)
      assert response["data"]["id"] == sub.id
      assert response["data"]["url"] == "https://example.com/hook"
      # Secret should NOT be exposed in show response
      refute Map.has_key?(response["data"], "secret")
    end

    test "returns 404 for non-existent subscription", %{
      conn: conn,
      plain_token: token,
      workspace: workspace
    } do
      fake_id = Ecto.UUID.generate()

      conn =
        conn
        |> put_req_header("authorization", "Bearer #{token}")
        |> get("/api/workspaces/#{workspace.slug}/webhooks/#{fake_id}")

      assert conn.status == 404
      response = json_response(conn, 404)
      assert response["error"] == "Not found"
    end
  end

  describe "PATCH /api/workspaces/:workspace_slug/webhooks/:id" do
    test "updates subscription URL", %{
      conn: conn,
      plain_token: token,
      workspace: workspace
    } do
      sub =
        webhook_subscription_fixture(%{
          workspace_id: workspace.id,
          url: "https://example.com/old-hook"
        })

      attrs = %{"url" => "https://example.com/new-hook"}

      conn =
        conn
        |> put_req_header("authorization", "Bearer #{token}")
        |> patch("/api/workspaces/#{workspace.slug}/webhooks/#{sub.id}", attrs)

      assert conn.status == 200
      response = json_response(conn, 200)
      assert response["data"]["url"] == "https://example.com/new-hook"
    end

    test "updates event_types", %{
      conn: conn,
      plain_token: token,
      workspace: workspace
    } do
      sub =
        webhook_subscription_fixture(%{
          workspace_id: workspace.id,
          event_types: ["projects.project_created"]
        })

      attrs = %{"event_types" => ["documents.document_created", "chat.message_sent"]}

      conn =
        conn
        |> put_req_header("authorization", "Bearer #{token}")
        |> patch("/api/workspaces/#{workspace.slug}/webhooks/#{sub.id}", attrs)

      assert conn.status == 200
      response = json_response(conn, 200)

      assert response["data"]["event_types"] == [
               "documents.document_created",
               "chat.message_sent"
             ]
    end

    test "deactivates subscription", %{
      conn: conn,
      plain_token: token,
      workspace: workspace
    } do
      sub =
        webhook_subscription_fixture(%{
          workspace_id: workspace.id,
          is_active: true
        })

      attrs = %{"is_active" => false}

      conn =
        conn
        |> put_req_header("authorization", "Bearer #{token}")
        |> patch("/api/workspaces/#{workspace.slug}/webhooks/#{sub.id}", attrs)

      assert conn.status == 200
      response = json_response(conn, 200)
      assert response["data"]["is_active"] == false
    end

    test "returns 404 for non-existent subscription", %{
      conn: conn,
      plain_token: token,
      workspace: workspace
    } do
      fake_id = Ecto.UUID.generate()

      conn =
        conn
        |> put_req_header("authorization", "Bearer #{token}")
        |> patch("/api/workspaces/#{workspace.slug}/webhooks/#{fake_id}", %{
          "url" => "https://x.com"
        })

      assert conn.status == 404
    end
  end

  describe "DELETE /api/workspaces/:workspace_slug/webhooks/:id" do
    test "deletes subscription", %{
      conn: conn,
      plain_token: token,
      workspace: workspace
    } do
      sub =
        webhook_subscription_fixture(%{
          workspace_id: workspace.id,
          url: "https://example.com/to-delete"
        })

      conn =
        conn
        |> put_req_header("authorization", "Bearer #{token}")
        |> delete("/api/workspaces/#{workspace.slug}/webhooks/#{sub.id}")

      assert conn.status == 200
      response = json_response(conn, 200)
      assert response["data"]["id"] == sub.id
      assert response["data"]["deleted"] == true
    end

    test "returns 404 on subsequent GET after delete", %{
      conn: conn,
      plain_token: token,
      workspace: workspace
    } do
      sub =
        webhook_subscription_fixture(%{
          workspace_id: workspace.id,
          url: "https://example.com/to-delete"
        })

      # Delete
      conn
      |> put_req_header("authorization", "Bearer #{token}")
      |> delete("/api/workspaces/#{workspace.slug}/webhooks/#{sub.id}")

      # Verify deleted
      conn =
        build_conn()
        |> put_req_header("authorization", "Bearer #{token}")
        |> get("/api/workspaces/#{workspace.slug}/webhooks/#{sub.id}")

      assert conn.status == 404
    end
  end
end
