defmodule EntityRelationshipManager.TraversalController do
  use EntityRelationshipManager, :controller

  alias EntityRelationshipManager.Plugs.AuthorizePlug

  plug(AuthorizePlug, [action: :traverse] when action in [:neighbors, :paths, :traverse])

  def neighbors(conn, %{"id" => entity_id} = params) do
    workspace_id = conn.assigns.workspace_id

    opts =
      []
      |> maybe_put_opt(:direction, params["direction"])
      |> maybe_put_opt(:entity_type, params["entity_type"])
      |> maybe_put_opt(:edge_type, params["edge_type"])

    case EntityRelationshipManager.get_neighbors(workspace_id, entity_id, opts) do
      {:ok, entities} ->
        conn
        |> put_status(:ok)
        |> put_view(EntityRelationshipManager.Views.TraversalJSON)
        |> render("neighbors.json", entities: entities)

      {:error, reason} ->
        handle_error(conn, reason)
    end
  end

  def paths(conn, %{"id" => source_id, "target_id" => target_id} = params) do
    workspace_id = conn.assigns.workspace_id

    opts =
      []
      |> maybe_put_int_opt(:max_depth, params["max_depth"])

    case EntityRelationshipManager.find_paths(workspace_id, source_id, target_id, opts) do
      {:ok, paths} ->
        conn
        |> put_status(:ok)
        |> put_view(EntityRelationshipManager.Views.TraversalJSON)
        |> render("paths.json", paths: paths)

      {:error, reason} ->
        handle_error(conn, reason)
    end
  end

  def traverse(conn, params) do
    workspace_id = conn.assigns.workspace_id
    start_id = params["start_id"]

    unless start_id do
      conn
      |> put_status(:bad_request)
      |> json(%{error: "bad_request", message: "start_id is required"})
      |> halt()
    else
      opts =
        [start_id: start_id]
        |> maybe_put_opt(:direction, params["direction"])
        |> maybe_put_int_opt(:max_depth, params["max_depth"])
        |> maybe_put_int_opt(:limit, params["limit"])

      case EntityRelationshipManager.traverse(workspace_id, opts) do
        {:ok, entities} ->
          conn
          |> put_status(:ok)
          |> put_view(EntityRelationshipManager.Views.TraversalJSON)
          |> render("traverse.json", entities: entities)

        {:error, reason} ->
          handle_error(conn, reason)
      end
    end
  end

  defp maybe_put_opt(opts, _key, nil), do: opts
  defp maybe_put_opt(opts, key, value), do: Keyword.put(opts, key, value)

  defp maybe_put_int_opt(opts, _key, nil), do: opts

  defp maybe_put_int_opt(opts, key, value) when is_binary(value) do
    case Integer.parse(value) do
      {int, ""} -> Keyword.put(opts, key, int)
      _ -> opts
    end
  end

  defp maybe_put_int_opt(opts, key, value) when is_integer(value) do
    Keyword.put(opts, key, value)
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
