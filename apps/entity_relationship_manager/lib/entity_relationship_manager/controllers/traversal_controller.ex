defmodule EntityRelationshipManager.TraversalController do
  use EntityRelationshipManager, :controller

  alias EntityRelationshipManager.Plugs.AuthorizePlug

  plug(AuthorizePlug, [action: :traverse] when action in [:neighbors, :paths, :traverse])

  alias EntityRelationshipManager.ControllerHelpers

  @max_depth 10
  @valid_directions ~w(in out both)

  def neighbors(conn, %{"id" => entity_id} = params) do
    workspace_id = conn.assigns.workspace_id

    with :ok <- validate_direction(params["direction"]) do
      opt_fields = [
        {:direction, :string, "direction"},
        {:entity_type, :string, "entity_type"},
        {:edge_type, :string, "edge_type"},
        {:limit, :integer, "limit"},
        {:offset, :integer, "offset"}
      ]

      case ControllerHelpers.build_opts(conn, params, opt_fields) do
        {:ok, opts} ->
          case EntityRelationshipManager.get_neighbors(workspace_id, entity_id, opts) do
            {:ok, entities} ->
              limit = Keyword.get(opts, :limit, 100)
              offset = Keyword.get(opts, :offset, 0)
              meta = %{total: length(entities), limit: limit, offset: offset}

              conn
              |> put_status(:ok)
              |> put_view(EntityRelationshipManager.Views.TraversalJSON)
              |> render("neighbors.json", entities: entities, meta: meta)

            {:error, reason} ->
              handle_error(conn, reason)
          end

        {:error, conn} ->
          conn
      end
    else
      {:error, message} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{error: "invalid_direction", message: message})
    end
  end

  def paths(conn, %{"id" => source_id, "target_id" => target_id} = params) do
    workspace_id = conn.assigns.workspace_id

    # "depth" param maps to :max_depth opt
    opt_fields = [{:max_depth, :integer, "max_depth"}, {:max_depth, :integer, "depth"}]

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

  def traverse(conn, %{"start_id" => start_id} = params) do
    workspace_id = conn.assigns.workspace_id

    # Parse depth from "depth" or "max_depth" param
    raw_depth = params["depth"] || params["max_depth"]

    with :ok <- validate_direction(params["direction"]),
         {:ok, depth} <- parse_depth(raw_depth) do
      opt_fields = [
        {:direction, :string, "direction"},
        {:limit, :integer, "limit"}
      ]

      case ControllerHelpers.build_opts(conn, params, opt_fields) do
        {:ok, opts} ->
          opts = Keyword.put(opts, :start_id, start_id)
          opts = if depth, do: Keyword.put(opts, :max_depth, depth), else: opts
          do_traverse(conn, workspace_id, opts, depth || 1)

        {:error, conn} ->
          conn
      end
    else
      {:error, message} when is_binary(message) ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{error: "invalid_depth", message: message})
    end
  end

  def traverse(conn, _params) do
    conn
    |> put_status(:unprocessable_entity)
    |> json(%{error: "missing_start_id", message: "start_id is required"})
    |> halt()
  end

  defp do_traverse(conn, workspace_id, opts, depth) do
    case EntityRelationshipManager.traverse(workspace_id, opts) do
      {:ok, entities} when is_list(entities) ->
        meta = %{depth: depth}

        conn
        |> put_status(:ok)
        |> put_view(EntityRelationshipManager.Views.TraversalJSON)
        |> render("traverse.json", entities: entities, meta: meta)

      {:ok, %{nodes: nodes, edges: edges}} ->
        meta = %{depth: depth}

        conn
        |> put_status(:ok)
        |> put_view(EntityRelationshipManager.Views.TraversalJSON)
        |> render("traverse.json", entities: nodes, edges: edges, meta: meta)

      {:error, reason} ->
        handle_error(conn, reason)
    end
  end

  defp validate_direction(nil), do: :ok

  defp validate_direction(dir) when dir in @valid_directions, do: :ok

  defp validate_direction(_dir) do
    {:error, "direction must be one of: in, out, both"}
  end

  defp parse_depth(nil), do: {:ok, nil}

  defp parse_depth(depth) when is_binary(depth) do
    case Integer.parse(depth) do
      {int, ""} when int > 0 and int <= @max_depth -> {:ok, int}
      {int, ""} when int > @max_depth -> {:error, "depth must not exceed 10"}
      {int, ""} when int <= 0 -> {:error, "depth must be a positive integer"}
      _ -> {:error, "depth must be a valid integer"}
    end
  end

  defp parse_depth(depth) when is_integer(depth) and depth > 0 and depth <= @max_depth,
    do: {:ok, depth}

  defp parse_depth(depth) when is_integer(depth) and depth > @max_depth,
    do: {:error, "depth must not exceed 10"}

  defp parse_depth(_), do: {:error, "depth must be a positive integer"}

  defp handle_error(conn, :not_found) do
    conn
    |> put_status(:not_found)
    |> json(%{error: "not_found", message: "Resource not found"})
  end

  defp handle_error(conn, _reason) do
    conn
    |> put_status(:unprocessable_entity)
    |> put_view(EntityRelationshipManager.Views.ErrorJSON)
    |> render("422.json")
  end
end
