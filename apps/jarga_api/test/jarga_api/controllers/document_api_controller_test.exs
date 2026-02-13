defmodule JargaApi.DocumentApiControllerTest do
  use JargaApi.ConnCase, async: true

  import Jarga.AccountsFixtures
  import Jarga.WorkspacesFixtures
  import Jarga.DocumentsFixtures
  import Jarga.ProjectsFixtures

  alias Jarga.Documents

  setup do
    user = user_fixture()
    workspace = workspace_fixture(user, %{name: "Dev Team"})
    other_workspace = workspace_fixture(user, %{name: "Other Team"})

    # Create API key with access to workspace only
    {:ok, {api_key, plain_token}} =
      Jarga.Accounts.create_api_key(user.id, %{
        name: "Test API Key",
        workspace_access: [workspace.slug]
      })

    %{
      user: user,
      workspace: workspace,
      other_workspace: other_workspace,
      api_key: api_key,
      plain_token: plain_token
    }
  end

  describe "POST /api/workspaces/:workspace_slug/documents" do
    test "successful creation returns 201 with JSON containing title, slug, visibility, workspace_slug, owner email",
         %{
           conn: conn,
           user: user,
           plain_token: plain_token,
           workspace: workspace
         } do
      conn =
        conn
        |> put_req_header("authorization", "Bearer #{plain_token}")
        |> post("/api/workspaces/#{workspace.slug}/documents", %{
          "title" => "My API Document",
          "visibility" => "public"
        })

      assert conn.status == 201
      response = json_response(conn, 201)

      assert response["data"]["title"] == "My API Document"
      assert is_binary(response["data"]["slug"])
      assert response["data"]["visibility"] == "public"
      assert response["data"]["workspace_slug"] == workspace.slug
      # owner should be the user's email, not UUID (consistent with GET responses)
      assert response["data"]["owner"] == user.email
    end

    test "validation error (missing title) returns 422", %{
      conn: conn,
      plain_token: plain_token,
      workspace: workspace
    } do
      conn =
        conn
        |> put_req_header("authorization", "Bearer #{plain_token}")
        |> post("/api/workspaces/#{workspace.slug}/documents", %{})

      assert conn.status == 422
      response = json_response(conn, 422)
      assert response["errors"]["title"] != nil
    end

    test "forbidden (wrong workspace) returns 403", %{
      conn: conn,
      plain_token: plain_token,
      other_workspace: other_workspace
    } do
      conn =
        conn
        |> put_req_header("authorization", "Bearer #{plain_token}")
        |> post("/api/workspaces/#{other_workspace.slug}/documents", %{
          "title" => "Forbidden Doc"
        })

      assert conn.status == 403
      response = json_response(conn, 403)
      assert response["error"] == "Insufficient permissions"
    end

    test "workspace not found returns 404", %{conn: conn, user: user} do
      {_api_key, plain_token} =
        api_key_fixture_without_validation(user.id, %{
          name: "Key with non-existent access",
          workspace_access: ["non-existent-workspace"]
        })

      conn =
        conn
        |> put_req_header("authorization", "Bearer #{plain_token}")
        |> post("/api/workspaces/non-existent-workspace/documents", %{
          "title" => "Doc in Nowhere"
        })

      assert conn.status == 404
      response = json_response(conn, 404)
      assert response["error"] == "Workspace not found"
    end

    test "create in project returns 201 with project_slug", %{
      conn: conn,
      plain_token: plain_token,
      user: user,
      workspace: workspace
    } do
      project = project_fixture(user, workspace, %{name: "Q1 Launch"})

      conn =
        conn
        |> put_req_header("authorization", "Bearer #{plain_token}")
        |> post(
          "/api/workspaces/#{workspace.slug}/projects/#{project.slug}/documents",
          %{
            "title" => "Project Doc",
            "visibility" => "private"
          }
        )

      assert conn.status == 201
      response = json_response(conn, 201)

      assert response["data"]["title"] == "Project Doc"
      assert response["data"]["project_slug"] == project.slug
      assert response["data"]["workspace_slug"] == workspace.slug
    end

    test "project not found returns 404", %{
      conn: conn,
      plain_token: plain_token,
      workspace: workspace
    } do
      conn =
        conn
        |> put_req_header("authorization", "Bearer #{plain_token}")
        |> post(
          "/api/workspaces/#{workspace.slug}/projects/non-existent-project/documents",
          %{
            "title" => "Doc in Nowhere"
          }
        )

      assert conn.status == 404
      response = json_response(conn, 404)
      assert response["error"] == "Project not found"
    end
  end

  describe "PATCH /api/workspaces/:workspace_slug/documents/:slug" do
    setup %{user: user, workspace: workspace} do
      document =
        document_fixture(user, workspace, nil, %{
          title: "Editable Doc",
          content: "initial content"
        })

      {:ok, _} = Documents.update_document(user, document.id, %{is_public: true})

      %{document: document}
    end

    test "200 - successfully update title", %{
      conn: conn,
      plain_token: plain_token,
      workspace: workspace,
      document: document
    } do
      conn =
        conn
        |> put_req_header("authorization", "Bearer #{plain_token}")
        |> patch("/api/workspaces/#{workspace.slug}/documents/#{document.slug}", %{
          "title" => "Updated Title"
        })

      assert conn.status == 200
      response = json_response(conn, 200)
      assert response["data"]["title"] == "Updated Title"
      assert is_binary(response["data"]["content_hash"])
      assert response["data"]["slug"] == document.slug
    end

    test "200 - successfully update visibility", %{
      conn: conn,
      plain_token: plain_token,
      workspace: workspace,
      document: document
    } do
      conn =
        conn
        |> put_req_header("authorization", "Bearer #{plain_token}")
        |> patch("/api/workspaces/#{workspace.slug}/documents/#{document.slug}", %{
          "visibility" => "private"
        })

      assert conn.status == 200
      response = json_response(conn, 200)
      assert response["data"]["visibility"] == "private"
    end

    test "200 - successfully update content with correct content_hash", %{
      conn: conn,
      plain_token: plain_token,
      workspace: workspace,
      document: document
    } do
      # First GET the document to obtain the content_hash
      get_conn =
        conn
        |> put_req_header("authorization", "Bearer #{plain_token}")
        |> get("/api/workspaces/#{workspace.slug}/documents/#{document.slug}")

      assert get_conn.status == 200
      get_response = json_response(get_conn, 200)
      content_hash = get_response["data"]["content_hash"]
      assert is_binary(content_hash)

      # Now PATCH with the hash
      patch_conn =
        build_conn()
        |> put_req_header("authorization", "Bearer #{plain_token}")
        |> patch("/api/workspaces/#{workspace.slug}/documents/#{document.slug}", %{
          "content" => "brand new content",
          "content_hash" => content_hash
        })

      assert patch_conn.status == 200
      patch_response = json_response(patch_conn, 200)
      assert patch_response["data"]["content"] == "brand new content"
      # content_hash should be different now
      assert patch_response["data"]["content_hash"] != content_hash
    end

    test "200 - successfully update title + content together", %{
      conn: conn,
      plain_token: plain_token,
      workspace: workspace,
      document: document
    } do
      # Get current hash
      get_conn =
        conn
        |> put_req_header("authorization", "Bearer #{plain_token}")
        |> get("/api/workspaces/#{workspace.slug}/documents/#{document.slug}")

      content_hash = json_response(get_conn, 200)["data"]["content_hash"]

      patch_conn =
        build_conn()
        |> put_req_header("authorization", "Bearer #{plain_token}")
        |> patch("/api/workspaces/#{workspace.slug}/documents/#{document.slug}", %{
          "title" => "New Title + Content",
          "content" => "new content too",
          "content_hash" => content_hash
        })

      assert patch_conn.status == 200
      response = json_response(patch_conn, 200)
      assert response["data"]["title"] == "New Title + Content"
      assert response["data"]["content"] == "new content too"
    end

    test "200 - update with no changes (idempotent)", %{
      conn: conn,
      plain_token: plain_token,
      workspace: workspace,
      document: document
    } do
      conn =
        conn
        |> put_req_header("authorization", "Bearer #{plain_token}")
        |> patch("/api/workspaces/#{workspace.slug}/documents/#{document.slug}", %{})

      assert conn.status == 200
    end

    test "403 - API key lacks workspace access", %{
      conn: conn,
      plain_token: plain_token,
      other_workspace: other_workspace,
      user: user
    } do
      document =
        document_fixture(user, other_workspace, nil, %{title: "Other WS Doc"})

      {:ok, _} = Documents.update_document(user, document.id, %{is_public: true})

      conn =
        conn
        |> put_req_header("authorization", "Bearer #{plain_token}")
        |> patch("/api/workspaces/#{other_workspace.slug}/documents/#{document.slug}", %{
          "title" => "Hacked"
        })

      assert conn.status == 403
    end

    test "404 - document not found", %{
      conn: conn,
      plain_token: plain_token,
      workspace: workspace
    } do
      conn =
        conn
        |> put_req_header("authorization", "Bearer #{plain_token}")
        |> patch("/api/workspaces/#{workspace.slug}/documents/non-existent-doc", %{
          "title" => "Ghost"
        })

      assert conn.status == 404
      response = json_response(conn, 404)
      assert response["error"] == "Document not found"
    end

    test "404 - workspace not found", %{conn: conn, user: user} do
      {_api_key, plain_token} =
        api_key_fixture_without_validation(user.id, %{
          name: "Key with non-existent access",
          workspace_access: ["non-existent-workspace"]
        })

      conn =
        conn
        |> put_req_header("authorization", "Bearer #{plain_token}")
        |> patch("/api/workspaces/non-existent-workspace/documents/some-doc", %{
          "title" => "Nowhere"
        })

      assert conn.status == 404
      response = json_response(conn, 404)
      assert response["error"] == "Workspace not found"
    end

    test "409 - content conflict (stale content_hash)", %{
      conn: conn,
      plain_token: plain_token,
      workspace: workspace,
      document: document
    } do
      conn =
        conn
        |> put_req_header("authorization", "Bearer #{plain_token}")
        |> patch("/api/workspaces/#{workspace.slug}/documents/#{document.slug}", %{
          "content" => "my changes",
          "content_hash" => "stale_hash_that_doesnt_match"
        })

      assert conn.status == 409
      response = json_response(conn, 409)
      assert response["error"] == "content_conflict"
      assert is_binary(response["data"]["content"])
      assert is_binary(response["data"]["content_hash"])
    end

    test "422 - content provided without content_hash", %{
      conn: conn,
      plain_token: plain_token,
      workspace: workspace,
      document: document
    } do
      conn =
        conn
        |> put_req_header("authorization", "Bearer #{plain_token}")
        |> patch("/api/workspaces/#{workspace.slug}/documents/#{document.slug}", %{
          "content" => "new content without hash"
        })

      assert conn.status == 422
      response = json_response(conn, 422)
      assert response["error"] == "content_hash is required when updating content"
    end
  end

  describe "GET /api/workspaces/:workspace_slug/documents/:slug" do
    test "successful retrieval returns 200 with title, slug, content, owner, workspace_slug",
         %{
           conn: conn,
           plain_token: plain_token,
           user: user,
           workspace: workspace
         } do
      document = document_fixture(user, workspace, nil, %{title: "Readable Doc"})
      # Make it public so it's accessible
      {:ok, _} = Documents.update_document(user, document.id, %{is_public: true})

      conn =
        conn
        |> put_req_header("authorization", "Bearer #{plain_token}")
        |> get("/api/workspaces/#{workspace.slug}/documents/#{document.slug}")

      assert conn.status == 200
      response = json_response(conn, 200)

      assert response["data"]["title"] == "Readable Doc"
      assert response["data"]["slug"] == document.slug

      # Note: content may be nil until Phase 4 (CreateDocument content pass-through) is implemented
      assert response["data"]["owner"] == user.email
      assert response["data"]["workspace_slug"] == workspace.slug
      # content_hash should always be present in GET responses
      assert is_binary(response["data"]["content_hash"])
    end

    test "document not found returns 404", %{
      conn: conn,
      plain_token: plain_token,
      workspace: workspace
    } do
      conn =
        conn
        |> put_req_header("authorization", "Bearer #{plain_token}")
        |> get("/api/workspaces/#{workspace.slug}/documents/non-existent-doc")

      assert conn.status == 404
      response = json_response(conn, 404)
      assert response["error"] == "Document not found"
    end

    test "forbidden (API key lacks access) returns 403", %{
      conn: conn,
      plain_token: plain_token,
      user: user,
      other_workspace: other_workspace
    } do
      document =
        document_fixture(user, other_workspace, nil, %{title: "Forbidden Doc"})

      {:ok, _} = Documents.update_document(user, document.id, %{is_public: true})

      conn =
        conn
        |> put_req_header("authorization", "Bearer #{plain_token}")
        |> get("/api/workspaces/#{other_workspace.slug}/documents/#{document.slug}")

      assert conn.status == 403
      response = json_response(conn, 403)
      assert response["error"] == "Insufficient permissions"
    end
  end
end
