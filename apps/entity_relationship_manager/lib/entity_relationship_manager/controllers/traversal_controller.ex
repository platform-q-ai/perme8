defmodule EntityRelationshipManager.TraversalController do
  use EntityRelationshipManager, :controller

  alias EntityRelationshipManager.Plugs.AuthorizePlug

  plug(AuthorizePlug, [action: :traverse] when action in [:neighbors, :paths, :traverse])

  alias EntityRelationshipManager.ControllerHelpers

  def neighbors(conn, %{"id" => entity_id} = params) do
    workspace_id = conn.assigns.workspace_id

    opt_fields = [
      {:direction, :string, "direction"},
      {:entity_type, :string, "entity_type"},
      {:edge_type, :string, "edge_type"}
    ]

    case ControllerHelpers.build_opts(conn, params, opt_fields) do
      {:ok, opts} ->
        case EntityRelationshipManager.get_neighbors(workspace_id, entity_id, opts) do
          {:ok, entities} ->
            conn
            |> put_status(:ok)
            |> put_view(EntityRelationshipManager.Views.TraversalJSON)
            |> render("neighbors.json", entities: entities)

          {:error, reason} ->
            handle_error(conn, reason)
        end

      {:error, conn} ->
        conn
    end
  end

  def paths(conn, %{"id" => source_id, "target_id" => target_id} = params) do
    workspace_id = conn.assigns.workspace_id

    opt_fields = [{:max_depth, :integer, "max_depth"}]

    case ControllerHelpers.build_opts(conn, params, opt_fields) do
      {:ok, opts} ->
        case EntityRelationshipManager.find_paths(workspace_id, source_id, target_id, opts) do
          {:ok, paths} ->
            conn
            |> put_status(:ok)
            |> put_view(EntityRelationshipManager.Views.TraversalJSON)
            |> render("paths.json", paths: paths)

          {:error, reason} ->
            handle_error(conn, reason)
        end

      {:error, conn} ->
        conn
    end
  end

  def traverse(conn, params) do
    workspace_id = conn.assigns.workspace_id
    start_id = params["start_id"]

    if start_id do
      opt_fields = [
        {:direction, :string, "direction"},
        {:max_depth, :integer, "max_depth"},
        {:limit, :integer, "limit"}
      ]

      case ControllerHelpers.build_opts(conn, params, opt_fields) do
        {:ok, opts} ->
          opts = Keyword.put(opts, :start_id, start_id)

          case EntityRelationshipManager.traverse(workspace_id, opts) do
            {:ok, entities} ->
              conn
              |> put_status(:ok)
              |> put_view(EntityRelationshipManager.Views.TraversalJSON)
              |> render("traverse.json", entities: entities)

            {:error, reason} ->
              handle_error(conn, reason)
          end

        {:error, conn} ->
          conn
      end
    else
      conn
      |> put_status(:bad_request)
      |> json(%{error: "bad_request", message: "start_id is required"})
      |> halt()
    end
  end

  defp handle_error(conn, :not_found) do
    conn
    |> put_status(:not_found)
    |> put_view(EntityRelationshipManager.Views.ErrorJSON)
    |> render("404.json")
  end

  defp handle_error(conn, _reason) do
    conn
    |> put_status(:unprocessable_entity)
    |> put_view(EntityRelationshipManager.Views.ErrorJSON)
    |> render("422.json")
  end
end
