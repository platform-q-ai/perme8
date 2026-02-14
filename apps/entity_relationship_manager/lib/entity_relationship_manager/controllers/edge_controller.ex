defmodule EntityRelationshipManager.EdgeController do
  use EntityRelationshipManager, :controller

  alias EntityRelationshipManager.Plugs.AuthorizePlug

  plug(AuthorizePlug, [action: :create_edge] when action in [:create, :bulk_create])
  plug(AuthorizePlug, [action: :read_edge] when action in [:index, :show])
  plug(AuthorizePlug, [action: :update_edge] when action in [:update])
  plug(AuthorizePlug, [action: :delete_edge] when action in [:delete])

  def create(conn, params) do
    workspace_id = conn.assigns.workspace_id

    attrs = %{
      type: params["type"],
      source_id: params["source_id"],
      target_id: params["target_id"],
      properties: params["properties"] || %{}
    }

    case EntityRelationshipManager.create_edge(workspace_id, attrs) do
      {:ok, edge} ->
        conn
        |> put_status(:created)
        |> put_view(EntityRelationshipManager.Views.EdgeJSON)
        |> render("show.json", edge: edge)

      {:error, reason} ->
        handle_error(conn, reason)
    end
  end

  def index(conn, params) do
    workspace_id = conn.assigns.workspace_id

    filters =
      %{}
      |> maybe_put(:type, params["type"])
      |> maybe_put_int(:limit, params["limit"])
      |> maybe_put_int(:offset, params["offset"])

    case EntityRelationshipManager.list_edges(workspace_id, filters) do
      {:ok, edges} ->
        conn
        |> put_status(:ok)
        |> put_view(EntityRelationshipManager.Views.EdgeJSON)
        |> render("index.json", edges: edges)

      {:error, reason} ->
        handle_error(conn, reason)
    end
  end

  def show(conn, %{"id" => id}) do
    workspace_id = conn.assigns.workspace_id

    case EntityRelationshipManager.get_edge(workspace_id, id) do
      {:ok, edge} ->
        conn
        |> put_status(:ok)
        |> put_view(EntityRelationshipManager.Views.EdgeJSON)
        |> render("show.json", edge: edge)

      {:error, :not_found} ->
        conn
        |> put_status(:not_found)
        |> put_view(EntityRelationshipManager.Views.ErrorJSON)
        |> render("404.json")

      {:error, reason} ->
        handle_error(conn, reason)
    end
  end

  def update(conn, %{"id" => id} = params) do
    workspace_id = conn.assigns.workspace_id
    properties = params["properties"] || %{}

    case EntityRelationshipManager.update_edge(workspace_id, id, properties) do
      {:ok, edge} ->
        conn
        |> put_status(:ok)
        |> put_view(EntityRelationshipManager.Views.EdgeJSON)
        |> render("show.json", edge: edge)

      {:error, :not_found} ->
        conn
        |> put_status(:not_found)
        |> put_view(EntityRelationshipManager.Views.ErrorJSON)
        |> render("404.json")

      {:error, reason} ->
        handle_error(conn, reason)
    end
  end

  def delete(conn, %{"id" => id}) do
    workspace_id = conn.assigns.workspace_id

    case EntityRelationshipManager.delete_edge(workspace_id, id) do
      {:ok, edge} ->
        conn
        |> put_status(:ok)
        |> put_view(EntityRelationshipManager.Views.EdgeJSON)
        |> render("show.json", edge: edge)

      {:error, :not_found} ->
        conn
        |> put_status(:not_found)
        |> put_view(EntityRelationshipManager.Views.ErrorJSON)
        |> render("404.json")

      {:error, reason} ->
        handle_error(conn, reason)
    end
  end

  def bulk_create(conn, params) do
    workspace_id = conn.assigns.workspace_id

    edges =
      (params["edges"] || [])
      |> Enum.map(fn e ->
        %{
          type: e["type"],
          source_id: e["source_id"],
          target_id: e["target_id"],
          properties: e["properties"] || %{}
        }
      end)

    case EntityRelationshipManager.bulk_create_edges(workspace_id, edges) do
      {:ok, created} when is_list(created) ->
        conn
        |> put_status(:created)
        |> put_view(EntityRelationshipManager.Views.EdgeJSON)
        |> render("bulk.json", edges: created, errors: [])

      {:ok, %{created: created, errors: errors}} ->
        conn
        |> put_status(:created)
        |> put_view(EntityRelationshipManager.Views.EdgeJSON)
        |> render("bulk.json", edges: created, errors: errors)

      {:error, reason} ->
        handle_error(conn, reason)
    end
  end

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)

  defp maybe_put_int(map, _key, nil), do: map

  defp maybe_put_int(map, key, value) when is_binary(value) do
    case Integer.parse(value) do
      {int, ""} -> Map.put(map, key, int)
      _ -> map
    end
  end

  defp maybe_put_int(map, key, value) when is_integer(value) do
    Map.put(map, key, value)
  end

  defp handle_error(conn, :schema_not_found) do
    conn
    |> put_status(:not_found)
    |> put_view(EntityRelationshipManager.Views.ErrorJSON)
    |> render("404.json")
  end

  defp handle_error(conn, :source_not_found) do
    conn
    |> put_status(:unprocessable_entity)
    |> json(%{error: "unprocessable_entity", message: "Source entity not found"})
  end

  defp handle_error(conn, :target_not_found) do
    conn
    |> put_status(:unprocessable_entity)
    |> json(%{error: "unprocessable_entity", message: "Target entity not found"})
  end

  defp handle_error(conn, {:validation_errors, errors}) do
    conn
    |> put_status(:unprocessable_entity)
    |> json(%{error: "validation_errors", errors: errors})
  end

  defp handle_error(conn, :empty_batch) do
    conn
    |> put_status(:bad_request)
    |> put_view(EntityRelationshipManager.Views.ErrorJSON)
    |> render("400.json")
  end

  defp handle_error(conn, :batch_too_large) do
    conn
    |> put_status(:bad_request)
    |> json(%{error: "bad_request", message: "Batch size exceeds maximum of 1000"})
  end

  defp handle_error(conn, _reason) do
    conn
    |> put_status(:unprocessable_entity)
    |> put_view(EntityRelationshipManager.Views.ErrorJSON)
    |> render("422.json")
  end
end
