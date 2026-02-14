defmodule EntityRelationshipManager.TraversalControllerTest do
  use EntityRelationshipManager.ConnCase, async: true

  alias EntityRelationshipManager.UseCaseFixtures

  describe "neighbors/2" do
    test "returns neighbors for an entity", %{conn: conn} do
      {conn, ws_id} = authenticated_conn(conn)
      entity = UseCaseFixtures.entity(%{workspace_id: ws_id})
      neighbor = UseCaseFixtures.entity(%{id: UseCaseFixtures.valid_uuid2(), workspace_id: ws_id})

      EntityRelationshipManager.Mocks.GraphRepositoryMock
      |> expect(:get_neighbors, fn _wid, _id, _opts -> {:ok, [neighbor]} end)

      conn = get(conn, "/api/v1/workspaces/#{ws_id}/entities/#{entity.id}/neighbors")

      assert %{"data" => data} = json_response(conn, 200)
      assert length(data) == 1
      assert Enum.at(data, 0)["id"] == neighbor.id
    end

    test "accepts direction parameter", %{conn: conn} do
      {conn, ws_id} = authenticated_conn(conn)
      entity_id = UseCaseFixtures.valid_uuid()

      EntityRelationshipManager.Mocks.GraphRepositoryMock
      |> expect(:get_neighbors, fn _wid, _id, opts ->
        assert Keyword.get(opts, :direction) == "out"
        {:ok, []}
      end)

      conn =
        get(conn, "/api/v1/workspaces/#{ws_id}/entities/#{entity_id}/neighbors?direction=out")

      assert json_response(conn, 200)
    end

    test "guest can traverse", %{conn: conn} do
      {conn, ws_id} = authenticated_conn(conn, role: :guest)
      entity_id = UseCaseFixtures.valid_uuid()

      EntityRelationshipManager.Mocks.GraphRepositoryMock
      |> expect(:get_neighbors, fn _wid, _id, _opts -> {:ok, []} end)

      conn = get(conn, "/api/v1/workspaces/#{ws_id}/entities/#{entity_id}/neighbors")

      assert json_response(conn, 200)
    end
  end

  describe "paths/2" do
    test "returns paths between two entities", %{conn: conn} do
      {conn, ws_id} = authenticated_conn(conn)
      source_id = UseCaseFixtures.valid_uuid()
      target_id = UseCaseFixtures.valid_uuid2()

      EntityRelationshipManager.Mocks.GraphRepositoryMock
      |> expect(:find_paths, fn _wid, _sid, _tid, _opts ->
        {:ok, [[source_id, target_id]]}
      end)

      conn =
        get(conn, "/api/v1/workspaces/#{ws_id}/entities/#{source_id}/paths/#{target_id}")

      assert %{"data" => paths} = json_response(conn, 200)
      assert length(paths) == 1
    end

    test "accepts max_depth parameter", %{conn: conn} do
      {conn, ws_id} = authenticated_conn(conn)
      source_id = UseCaseFixtures.valid_uuid()
      target_id = UseCaseFixtures.valid_uuid2()

      EntityRelationshipManager.Mocks.GraphRepositoryMock
      |> expect(:find_paths, fn _wid, _sid, _tid, opts ->
        assert Keyword.get(opts, :max_depth) == 3
        {:ok, []}
      end)

      conn =
        get(
          conn,
          "/api/v1/workspaces/#{ws_id}/entities/#{source_id}/paths/#{target_id}?max_depth=3"
        )

      assert json_response(conn, 200)
    end
  end

  describe "traverse/2" do
    test "traverses from a start entity", %{conn: conn} do
      {conn, ws_id} = authenticated_conn(conn)
      entity = UseCaseFixtures.entity(%{workspace_id: ws_id})
      start_id = entity.id

      EntityRelationshipManager.Mocks.GraphRepositoryMock
      |> expect(:traverse, fn _wid, sid, _opts ->
        assert sid == start_id
        {:ok, [entity]}
      end)

      conn = get(conn, "/api/v1/workspaces/#{ws_id}/traverse?start_id=#{start_id}")

      assert %{"data" => data} = json_response(conn, 200)
      assert length(data) == 1
    end

    test "returns 400 when start_id is missing", %{conn: conn} do
      {conn, ws_id} = authenticated_conn(conn)

      conn = get(conn, "/api/v1/workspaces/#{ws_id}/traverse")

      assert %{"error" => "bad_request"} = json_response(conn, 400)
    end

    test "accepts direction and max_depth parameters", %{conn: conn} do
      {conn, ws_id} = authenticated_conn(conn)
      start_id = UseCaseFixtures.valid_uuid()

      EntityRelationshipManager.Mocks.GraphRepositoryMock
      |> expect(:traverse, fn _wid, _sid, opts ->
        assert Keyword.get(opts, :direction) == "out"
        assert Keyword.get(opts, :max_depth) == 2
        {:ok, []}
      end)

      conn =
        get(
          conn,
          "/api/v1/workspaces/#{ws_id}/traverse?start_id=#{start_id}&direction=out&max_depth=2"
        )

      assert json_response(conn, 200)
    end
  end
end
