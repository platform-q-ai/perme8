defmodule EntityRelationshipManager.EntityController do
  use EntityRelationshipManager, :controller

  alias EntityRelationshipManager.Plugs.AuthorizePlug

  plug(AuthorizePlug, [action: :create_entity] when action in [:create, :bulk_create])
  plug(AuthorizePlug, [action: :read_entity] when action in [:index, :show])
  plug(AuthorizePlug, [action: :update_entity] when action in [:update, :bulk_update])
  plug(AuthorizePlug, [action: :delete_entity] when action in [:delete, :bulk_delete])

  def create(conn, params) do
    workspace_id = conn.assigns.workspace_id

    attrs = %{
      type: params["type"],
      properties: params["properties"] || %{}
    }

    case EntityRelationshipManager.create_entity(workspace_id, attrs) do
      {:ok, entity} ->
        conn
        |> put_status(:created)
        |> put_view(EntityRelationshipManager.Views.EntityJSON)
        |> render("show.json", entity: entity)

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

    case EntityRelationshipManager.list_entities(workspace_id, filters) do
      {:ok, entities} ->
        conn
        |> put_status(:ok)
        |> put_view(EntityRelationshipManager.Views.EntityJSON)
        |> render("index.json", entities: entities)

      {:error, reason} ->
        handle_error(conn, reason)
    end
  end

  def show(conn, %{"id" => id}) do
    workspace_id = conn.assigns.workspace_id

    case EntityRelationshipManager.get_entity(workspace_id, id) do
      {:ok, entity} ->
        conn
        |> put_status(:ok)
        |> put_view(EntityRelationshipManager.Views.EntityJSON)
        |> render("show.json", entity: entity)

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

    case EntityRelationshipManager.update_entity(workspace_id, id, properties) do
      {:ok, entity} ->
        conn
        |> put_status(:ok)
        |> put_view(EntityRelationshipManager.Views.EntityJSON)
        |> render("show.json", entity: entity)

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

    case EntityRelationshipManager.delete_entity(workspace_id, id) do
      {:ok, entity, deleted_edge_count} ->
        conn
        |> put_status(:ok)
        |> put_view(EntityRelationshipManager.Views.EntityJSON)
        |> render("delete.json", entity: entity, deleted_edge_count: deleted_edge_count)

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
    entities = normalize_bulk_entities(params["entities"] || [])

    case EntityRelationshipManager.bulk_create_entities(workspace_id, entities) do
      {:ok, created} when is_list(created) ->
        conn
        |> put_status(:created)
        |> put_view(EntityRelationshipManager.Views.EntityJSON)
        |> render("bulk.json", entities: created, errors: [])

      {:ok, %{created: created, errors: errors}} ->
        conn
        |> put_status(:created)
        |> put_view(EntityRelationshipManager.Views.EntityJSON)
        |> render("bulk.json", entities: created, errors: errors)

      {:error, reason} ->
        handle_error(conn, reason)
    end
  end

  def bulk_update(conn, params) do
    workspace_id = conn.assigns.workspace_id
    updates = normalize_bulk_updates(params["updates"] || [])

    case EntityRelationshipManager.bulk_update_entities(workspace_id, updates) do
      {:ok, updated} when is_list(updated) ->
        conn
        |> put_status(:ok)
        |> put_view(EntityRelationshipManager.Views.EntityJSON)
        |> render("bulk.json", entities: updated, errors: [])

      {:ok, %{updated: updated, errors: errors}} ->
        conn
        |> put_status(:ok)
        |> put_view(EntityRelationshipManager.Views.EntityJSON)
        |> render("bulk.json", entities: updated, errors: errors)

      {:error, reason} ->
        handle_error(conn, reason)
    end
  end

  def bulk_delete(conn, params) do
    workspace_id = conn.assigns.workspace_id
    entity_ids = params["entity_ids"] || []

    case EntityRelationshipManager.bulk_delete_entities(workspace_id, entity_ids) do
      {:ok, count} when is_integer(count) ->
        conn
        |> put_status(:ok)
        |> put_view(EntityRelationshipManager.Views.EntityJSON)
        |> render("bulk_delete.json", deleted_count: count, errors: [])

      {:ok, %{deleted_count: count, errors: errors}} ->
        conn
        |> put_status(:ok)
        |> put_view(EntityRelationshipManager.Views.EntityJSON)
        |> render("bulk_delete.json", deleted_count: count, errors: errors)

      {:error, reason} ->
        handle_error(conn, reason)
    end
  end

  defp normalize_bulk_entities(entities) do
    Enum.map(entities, fn e ->
      %{
        type: e["type"],
        properties: e["properties"] || %{}
      }
    end)
  end

  defp normalize_bulk_updates(updates) do
    Enum.map(updates, fn u ->
      %{
        id: u["id"],
        properties: u["properties"] || %{}
      }
    end)
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
