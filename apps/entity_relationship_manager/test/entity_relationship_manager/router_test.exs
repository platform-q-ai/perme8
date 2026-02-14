defmodule EntityRelationshipManager.RouterTest do
  use ExUnit.Case, async: true

  alias EntityRelationshipManager.Router

  @workspace_id "550e8400-e29b-41d4-a716-446655440000"
  @entity_id "660e8400-e29b-41d4-a716-446655440001"
  @target_id "770e8400-e29b-41d4-a716-446655440002"
  @edge_id "880e8400-e29b-41d4-a716-446655440003"

  describe "routes" do
    test "health check route exists" do
      assert_route(:get, "/health", EntityRelationshipManager.HealthController, :show)
    end

    test "schema routes exist" do
      assert_route(
        :get,
        "/api/v1/workspaces/#{@workspace_id}/schema",
        EntityRelationshipManager.SchemaController,
        :show
      )

      assert_route(
        :put,
        "/api/v1/workspaces/#{@workspace_id}/schema",
        EntityRelationshipManager.SchemaController,
        :update
      )
    end

    test "entity routes exist" do
      assert_route(
        :post,
        "/api/v1/workspaces/#{@workspace_id}/entities",
        EntityRelationshipManager.EntityController,
        :create
      )

      assert_route(
        :get,
        "/api/v1/workspaces/#{@workspace_id}/entities",
        EntityRelationshipManager.EntityController,
        :index
      )

      assert_route(
        :get,
        "/api/v1/workspaces/#{@workspace_id}/entities/#{@entity_id}",
        EntityRelationshipManager.EntityController,
        :show
      )

      assert_route(
        :put,
        "/api/v1/workspaces/#{@workspace_id}/entities/#{@entity_id}",
        EntityRelationshipManager.EntityController,
        :update
      )

      assert_route(
        :delete,
        "/api/v1/workspaces/#{@workspace_id}/entities/#{@entity_id}",
        EntityRelationshipManager.EntityController,
        :delete
      )
    end

    test "entity bulk routes exist" do
      assert_route(
        :post,
        "/api/v1/workspaces/#{@workspace_id}/entities/bulk",
        EntityRelationshipManager.EntityController,
        :bulk_create
      )

      assert_route(
        :put,
        "/api/v1/workspaces/#{@workspace_id}/entities/bulk",
        EntityRelationshipManager.EntityController,
        :bulk_update
      )

      assert_route(
        :delete,
        "/api/v1/workspaces/#{@workspace_id}/entities/bulk",
        EntityRelationshipManager.EntityController,
        :bulk_delete
      )
    end

    test "traversal routes exist" do
      assert_route(
        :get,
        "/api/v1/workspaces/#{@workspace_id}/entities/#{@entity_id}/neighbors",
        EntityRelationshipManager.TraversalController,
        :neighbors
      )

      assert_route(
        :get,
        "/api/v1/workspaces/#{@workspace_id}/entities/#{@entity_id}/paths/#{@target_id}",
        EntityRelationshipManager.TraversalController,
        :paths
      )

      assert_route(
        :get,
        "/api/v1/workspaces/#{@workspace_id}/traverse",
        EntityRelationshipManager.TraversalController,
        :traverse
      )
    end

    test "edge routes exist" do
      assert_route(
        :post,
        "/api/v1/workspaces/#{@workspace_id}/edges",
        EntityRelationshipManager.EdgeController,
        :create
      )

      assert_route(
        :get,
        "/api/v1/workspaces/#{@workspace_id}/edges",
        EntityRelationshipManager.EdgeController,
        :index
      )

      assert_route(
        :get,
        "/api/v1/workspaces/#{@workspace_id}/edges/#{@edge_id}",
        EntityRelationshipManager.EdgeController,
        :show
      )

      assert_route(
        :put,
        "/api/v1/workspaces/#{@workspace_id}/edges/#{@edge_id}",
        EntityRelationshipManager.EdgeController,
        :update
      )

      assert_route(
        :delete,
        "/api/v1/workspaces/#{@workspace_id}/edges/#{@edge_id}",
        EntityRelationshipManager.EdgeController,
        :delete
      )
    end

    test "edge bulk routes exist" do
      assert_route(
        :post,
        "/api/v1/workspaces/#{@workspace_id}/edges/bulk",
        EntityRelationshipManager.EdgeController,
        :bulk_create
      )
    end
  end

  defp assert_route(method, path, expected_plug, expected_action) do
    %{plug: plug, plug_opts: action} =
      Phoenix.Router.route_info(Router, method |> to_string() |> String.upcase(), path, "")

    assert plug == expected_plug, "Expected #{inspect(expected_plug)}, got #{inspect(plug)}"

    assert action == expected_action,
           "Expected action #{inspect(expected_action)}, got #{inspect(action)}"
  end
end
