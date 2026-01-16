defmodule JargaWeb.WorkspaceApiControllerTest do
  use JargaWeb.ConnCase, async: true

  import Jarga.AccountsFixtures
  import Jarga.WorkspacesFixtures
  import Jarga.DocumentsFixtures
  import Jarga.ProjectsFixtures

  alias Jarga.Documents

  setup do
    user = user_fixture()
    workspace1 = workspace_fixture(user, %{name: "Product Team"})
    workspace2 = workspace_fixture(user, %{name: "Engineering"})
    workspace3 = workspace_fixture(user, %{name: "Marketing"})

    # Create API key with access to workspace1 and workspace2 only
    {:ok, {api_key, plain_token}} =
      Jarga.Accounts.create_api_key(user.id, %{
        name: "Test API Key",
        workspace_access: [workspace1.slug, workspace2.slug]
      })

    %{
      user: user,
      workspace1: workspace1,
      workspace2: workspace2,
      workspace3: workspace3,
      api_key: api_key,
      plain_token: plain_token
    }
  end

  describe "GET /api/workspaces" do
    test "returns 200 with list of accessible workspaces", %{
      conn: conn,
      plain_token: plain_token,
      workspace1: workspace1,
      workspace2: workspace2
    } do
      conn =
        conn
        |> put_req_header("authorization", "Bearer #{plain_token}")
        |> get(~p"/api/workspaces")

      assert conn.status == 200
      response = json_response(conn, 200)
      assert is_list(response["data"])
      assert length(response["data"]) == 2

      workspace_slugs = Enum.map(response["data"], & &1["slug"])
      assert workspace1.slug in workspace_slugs
      assert workspace2.slug in workspace_slugs
    end

    test "returns workspaces with name and slug fields only (no IDs)", %{
      conn: conn,
      plain_token: plain_token
    } do
      conn =
        conn
        |> put_req_header("authorization", "Bearer #{plain_token}")
        |> get(~p"/api/workspaces")

      response = json_response(conn, 200)
      workspace = hd(response["data"])

      # Only name and slug, no ID
      refute Map.has_key?(workspace, "id")
      assert Map.has_key?(workspace, "name")
      assert Map.has_key?(workspace, "slug")
    end

    test "does not include documents or projects in list response", %{
      conn: conn,
      plain_token: plain_token,
      user: user,
      workspace1: workspace1
    } do
      # Create a document and project in workspace1
      document = document_fixture(user, workspace1, nil, %{title: "Test Doc"})
      {:ok, _} = Documents.update_document(user, document.id, %{is_public: true})
      _project = project_fixture(user, workspace1, %{name: "Test Project"})

      conn =
        conn
        |> put_req_header("authorization", "Bearer #{plain_token}")
        |> get(~p"/api/workspaces")

      response = json_response(conn, 200)
      workspace = Enum.find(response["data"], &(&1["slug"] == workspace1.slug))

      refute Map.has_key?(workspace, "documents")
      refute Map.has_key?(workspace, "projects")
    end

    test "returns empty list when API key has no workspace access", %{conn: conn, user: user} do
      # Create API key with no workspace access
      {:ok, {_api_key, plain_token}} =
        Jarga.Accounts.create_api_key(user.id, %{
          name: "No Access Key",
          workspace_access: []
        })

      conn =
        conn
        |> put_req_header("authorization", "Bearer #{plain_token}")
        |> get(~p"/api/workspaces")

      response = json_response(conn, 200)
      assert response["data"] == []
    end

    test "returns 401 when no Authorization header", %{conn: conn} do
      conn = get(conn, ~p"/api/workspaces")

      assert conn.status == 401
      response = json_response(conn, 401)
      assert response["error"] == "Invalid or revoked API key"
    end

    test "returns 401 when invalid API key", %{conn: conn} do
      conn =
        conn
        |> put_req_header("authorization", "Bearer invalid-token-12345")
        |> get(~p"/api/workspaces")

      assert conn.status == 401
      response = json_response(conn, 401)
      assert response["error"] == "Invalid or revoked API key"
    end

    test "returns 401 when revoked API key", %{
      conn: conn,
      user: user,
      api_key: api_key,
      plain_token: plain_token
    } do
      # Revoke the API key
      {:ok, _} = Jarga.Accounts.revoke_api_key(user.id, api_key.id)

      conn =
        conn
        |> put_req_header("authorization", "Bearer #{plain_token}")
        |> get(~p"/api/workspaces")

      assert conn.status == 401
      response = json_response(conn, 401)
      assert response["error"] == "Invalid or revoked API key"
    end
  end

  describe "GET /api/workspaces/:slug" do
    test "returns 200 with workspace details including documents and projects", %{
      conn: conn,
      plain_token: plain_token,
      user: user,
      workspace1: workspace1
    } do
      # Create public documents
      doc1 = document_fixture(user, workspace1, nil, %{title: "Product Spec"})
      {:ok, _} = Documents.update_document(user, doc1.id, %{is_public: true})
      doc2 = document_fixture(user, workspace1, nil, %{title: "Design Doc"})
      {:ok, _} = Documents.update_document(user, doc2.id, %{is_public: true})

      # Create projects
      _project1 = project_fixture(user, workspace1, %{name: "Q1 Launch"})
      _project2 = project_fixture(user, workspace1, %{name: "User Research"})

      conn =
        conn
        |> put_req_header("authorization", "Bearer #{plain_token}")
        |> get(~p"/api/workspaces/#{workspace1.slug}")

      assert conn.status == 200
      response = json_response(conn, 200)

      # Only name and slug, no ID
      refute Map.has_key?(response["data"], "id")
      assert response["data"]["name"] == workspace1.name
      assert response["data"]["slug"] == workspace1.slug

      assert length(response["data"]["documents"]) == 2
      assert length(response["data"]["projects"]) == 2

      # Verify document fields
      doc_titles = Enum.map(response["data"]["documents"], & &1["title"])
      assert "Product Spec" in doc_titles
      assert "Design Doc" in doc_titles

      # Verify project fields
      project_names = Enum.map(response["data"]["projects"], & &1["name"])
      assert "Q1 Launch" in project_names
      assert "User Research" in project_names
    end

    test "documents include title and slug only (no IDs)", %{
      conn: conn,
      plain_token: plain_token,
      user: user,
      workspace1: workspace1
    } do
      doc = document_fixture(user, workspace1, nil, %{title: "Test Doc"})
      {:ok, _} = Documents.update_document(user, doc.id, %{is_public: true})

      conn =
        conn
        |> put_req_header("authorization", "Bearer #{plain_token}")
        |> get(~p"/api/workspaces/#{workspace1.slug}")

      response = json_response(conn, 200)
      document = hd(response["data"]["documents"])

      # Only title and slug, no ID
      refute Map.has_key?(document, "id")
      assert Map.has_key?(document, "title")
      assert Map.has_key?(document, "slug")
    end

    test "projects include name and slug only (no IDs)", %{
      conn: conn,
      plain_token: plain_token,
      user: user,
      workspace1: workspace1
    } do
      _project = project_fixture(user, workspace1, %{name: "Test Project"})

      conn =
        conn
        |> put_req_header("authorization", "Bearer #{plain_token}")
        |> get(~p"/api/workspaces/#{workspace1.slug}")

      response = json_response(conn, 200)
      project = hd(response["data"]["projects"])

      # Only name and slug, no ID
      refute Map.has_key?(project, "id")
      assert Map.has_key?(project, "name")
      assert Map.has_key?(project, "slug")
    end

    test "returns 403 when API key lacks access to workspace", %{
      conn: conn,
      plain_token: plain_token,
      workspace3: workspace3
    } do
      conn =
        conn
        |> put_req_header("authorization", "Bearer #{plain_token}")
        |> get(~p"/api/workspaces/#{workspace3.slug}")

      assert conn.status == 403
      response = json_response(conn, 403)
      assert response["error"] == "Insufficient permissions"
    end

    test "returns 404 when workspace doesn't exist", %{conn: conn, user: user} do
      # Create API key with access to a non-existent workspace slug
      # (bypass validation since this tests the edge case where workspace
      # was deleted after API key was created)
      {_api_key, plain_token} =
        api_key_fixture_without_validation(user.id, %{
          name: "Key with non-existent access",
          workspace_access: ["non-existent-workspace"]
        })

      conn =
        conn
        |> put_req_header("authorization", "Bearer #{plain_token}")
        |> get(~p"/api/workspaces/non-existent-workspace")

      assert conn.status == 404
      response = json_response(conn, 404)
      assert response["error"] == "Workspace not found"
    end

    test "returns 401 when invalid API key", %{conn: conn, workspace1: workspace1} do
      conn =
        conn
        |> put_req_header("authorization", "Bearer invalid-token-12345")
        |> get(~p"/api/workspaces/#{workspace1.slug}")

      assert conn.status == 401
      response = json_response(conn, 401)
      assert response["error"] == "Invalid or revoked API key"
    end
  end
end
