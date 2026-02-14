defmodule EntityRelationshipManager.EdgeControllerTest do
  use EntityRelationshipManager.ConnCase, async: true

  alias EntityRelationshipManager.UseCaseFixtures

  describe "create/2" do
    test "creates an edge and returns 201", %{conn: conn} do
      {conn, ws_id} = authenticated_conn(conn)
      edge = UseCaseFixtures.edge(%{workspace_id: ws_id})
      schema = UseCaseFixtures.schema_definition(%{workspace_id: ws_id})
      source = UseCaseFixtures.entity(%{workspace_id: ws_id})
      target = UseCaseFixtures.entity(%{id: UseCaseFixtures.valid_uuid2(), workspace_id: ws_id})

      EntityRelationshipManager.Mocks.SchemaRepositoryMock
      |> expect(:get_schema, fn _wid -> {:ok, schema} end)

      EntityRelationshipManager.Mocks.GraphRepositoryMock
      |> expect(:create_edge, fn _wid, "WORKS_AT", _s, _t, _p -> {:ok, edge} end)

      conn =
        post(conn, "/api/v1/workspaces/#{ws_id}/edges", %{
          "type" => "WORKS_AT",
          "source_id" => source.id,
          "target_id" => target.id,
          "properties" => %{"role" => "Engineer"}
        })

      assert %{"data" => data} = json_response(conn, 201)
      assert data["type"] == "WORKS_AT"
    end

    test "returns 403 for guest role", %{conn: conn} do
      {conn, ws_id} = authenticated_conn(conn, role: :guest)

      conn =
        post(conn, "/api/v1/workspaces/#{ws_id}/edges", %{
          "type" => "WORKS_AT",
          "source_id" => UseCaseFixtures.valid_uuid(),
          "target_id" => UseCaseFixtures.valid_uuid2()
        })

      assert json_response(conn, 403)
    end

    test "returns 422 when endpoints not found", %{conn: conn} do
      {conn, ws_id} = authenticated_conn(conn)
      schema = UseCaseFixtures.schema_definition(%{workspace_id: ws_id})

      EntityRelationshipManager.Mocks.SchemaRepositoryMock
      |> expect(:get_schema, fn _wid -> {:ok, schema} end)

      EntityRelationshipManager.Mocks.GraphRepositoryMock
      |> expect(:create_edge, fn _wid, _type, _s, _t, _p -> {:error, :endpoints_not_found} end)

      conn =
        post(conn, "/api/v1/workspaces/#{ws_id}/edges", %{
          "type" => "WORKS_AT",
          "source_id" => UseCaseFixtures.valid_uuid(),
          "target_id" => UseCaseFixtures.valid_uuid2()
        })

      assert %{"errors" => _} = json_response(conn, 422)
    end
  end

  describe "index/2" do
    test "lists edges", %{conn: conn} do
      {conn, ws_id} = authenticated_conn(conn)
      edge = UseCaseFixtures.edge(%{workspace_id: ws_id})

      EntityRelationshipManager.Mocks.GraphRepositoryMock
      |> expect(:list_edges, fn _wid, _filters -> {:ok, [edge]} end)

      conn = get(conn, "/api/v1/workspaces/#{ws_id}/edges")

      assert %{"data" => data} = json_response(conn, 200)
      assert length(data) == 1
    end

    test "guest can read edges", %{conn: conn} do
      {conn, ws_id} = authenticated_conn(conn, role: :guest)

      EntityRelationshipManager.Mocks.GraphRepositoryMock
      |> expect(:list_edges, fn _wid, _filters -> {:ok, []} end)

      conn = get(conn, "/api/v1/workspaces/#{ws_id}/edges")

      assert json_response(conn, 200)
    end
  end

  describe "show/2" do
    test "returns a single edge", %{conn: conn} do
      {conn, ws_id} = authenticated_conn(conn)
      edge = UseCaseFixtures.edge(%{workspace_id: ws_id})

      EntityRelationshipManager.Mocks.GraphRepositoryMock
      |> expect(:get_edge, fn _wid, _id -> {:ok, edge} end)

      conn = get(conn, "/api/v1/workspaces/#{ws_id}/edges/#{edge.id}")

      assert %{"data" => data} = json_response(conn, 200)
      assert data["id"] == edge.id
    end

    test "returns 404 when edge not found", %{conn: conn} do
      {conn, ws_id} = authenticated_conn(conn)
      edge_id = UseCaseFixtures.valid_uuid()

      EntityRelationshipManager.Mocks.GraphRepositoryMock
      |> expect(:get_edge, fn _wid, _id -> {:error, :not_found} end)

      conn = get(conn, "/api/v1/workspaces/#{ws_id}/edges/#{edge_id}")

      assert json_response(conn, 404)
    end
  end

  describe "update/2" do
    test "updates an edge", %{conn: conn} do
      {conn, ws_id} = authenticated_conn(conn)
      edge = UseCaseFixtures.edge(%{workspace_id: ws_id})
      schema = UseCaseFixtures.schema_definition(%{workspace_id: ws_id})

      EntityRelationshipManager.Mocks.SchemaRepositoryMock
      |> expect(:get_schema, fn _wid -> {:ok, schema} end)

      EntityRelationshipManager.Mocks.GraphRepositoryMock
      |> expect(:get_edge, fn _wid, _id -> {:ok, edge} end)
      |> expect(:update_edge, fn _wid, _id, _props -> {:ok, edge} end)

      conn =
        put(conn, "/api/v1/workspaces/#{ws_id}/edges/#{edge.id}", %{
          "properties" => %{"role" => "CTO"}
        })

      assert %{"data" => _data} = json_response(conn, 200)
    end

    test "returns 403 for guest role", %{conn: conn} do
      {conn, ws_id} = authenticated_conn(conn, role: :guest)
      edge_id = UseCaseFixtures.valid_uuid()

      conn =
        put(conn, "/api/v1/workspaces/#{ws_id}/edges/#{edge_id}", %{
          "properties" => %{"role" => "CTO"}
        })

      assert json_response(conn, 403)
    end
  end

  describe "delete/2" do
    test "soft-deletes an edge", %{conn: conn} do
      {conn, ws_id} = authenticated_conn(conn)
      edge = UseCaseFixtures.edge(%{workspace_id: ws_id})

      EntityRelationshipManager.Mocks.GraphRepositoryMock
      |> expect(:soft_delete_edge, fn _wid, _id -> {:ok, edge} end)

      conn = delete(conn, "/api/v1/workspaces/#{ws_id}/edges/#{edge.id}")

      assert %{"data" => _data} = json_response(conn, 200)
    end

    test "returns 403 for guest role", %{conn: conn} do
      {conn, ws_id} = authenticated_conn(conn, role: :guest)
      edge_id = UseCaseFixtures.valid_uuid()

      conn = delete(conn, "/api/v1/workspaces/#{ws_id}/edges/#{edge_id}")

      assert json_response(conn, 403)
    end
  end

  describe "bulk_create/2" do
    test "bulk creates edges", %{conn: conn} do
      {conn, ws_id} = authenticated_conn(conn)
      edge = UseCaseFixtures.edge(%{workspace_id: ws_id})
      schema = UseCaseFixtures.schema_definition(%{workspace_id: ws_id})

      EntityRelationshipManager.Mocks.SchemaRepositoryMock
      |> expect(:get_schema, fn _wid -> {:ok, schema} end)

      EntityRelationshipManager.Mocks.GraphRepositoryMock
      |> expect(:bulk_create_edges, fn _wid, _edges -> {:ok, [edge]} end)

      conn =
        post(conn, "/api/v1/workspaces/#{ws_id}/edges/bulk", %{
          "edges" => [
            %{
              "type" => "WORKS_AT",
              "source_id" => UseCaseFixtures.valid_uuid(),
              "target_id" => UseCaseFixtures.valid_uuid2(),
              "properties" => %{"role" => "Engineer"}
            }
          ]
        })

      assert %{"data" => data, "errors" => []} = json_response(conn, 201)
      assert length(data) == 1
    end
  end
end
