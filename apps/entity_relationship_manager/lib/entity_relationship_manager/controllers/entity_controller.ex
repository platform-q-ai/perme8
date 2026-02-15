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

    filter_fields = [
      {:type, :string, "type"},
      {:limit, :integer, "limit"},
      {:offset, :integer, "offset"}
    ]

    case EntityRelationshipManager.ControllerHelpers.build_filters(conn, params, filter_fields) do
      {:ok, filters} ->
        do_list_entities(conn, workspace_id, filters)

      {:error, conn} ->
        conn
    end
  end

  defp do_list_entities(conn, workspace_id, filters) do
    case validate_pagination(filters) do
      {:error, message} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{error: "invalid_limit", message: message})

      :ok ->
        case EntityRelationshipManager.list_entities(workspace_id, filters) do
          {:ok, entities} ->
            meta = %{
              total: length(entities),
              limit: Map.get(filters, :limit, 100),
              offset: Map.get(filters, :offset, 0)
            }

            conn
            |> put_status(:ok)
            |> put_view(EntityRelationshipManager.Views.EntityJSON)
            |> render("index.json", entities: entities, meta: meta)

          {:error, reason} ->
            handle_error(conn, reason)
        end
    end
  end

  def show(conn, %{"id" => id} = params) do
    workspace_id = conn.assigns.workspace_id
    include_deleted = params["include_deleted"] == "true"
    opts = if include_deleted, do: [include_deleted: true], else: []

    case validate_uuid(id, "id") do
      :ok ->
        case EntityRelationshipManager.get_entity(workspace_id, id, opts) do
          {:ok, entity} ->
            conn
            |> put_status(:ok)
            |> put_view(EntityRelationshipManager.Views.EntityJSON)
            |> render("show.json", entity: entity)

          {:error, :not_found} ->
            conn
            |> put_status(:not_found)
            |> json(%{error: "not_found"})

          {:error, reason} ->
            handle_error(conn, reason)
        end

      {:error, message} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{error: "invalid_id", message: message})
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
        |> json(%{error: "not_found"})

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
        |> json(%{error: "not_found"})

      {:error, reason} ->
        handle_error(conn, reason)
    end
  end

  def bulk_create(conn, params) do
    workspace_id = conn.assigns.workspace_id
    entities = normalize_bulk_entities(params["entities"] || [])
    mode = parse_mode(params["mode"])
    opts = [mode: mode]

    case EntityRelationshipManager.bulk_create_entities(workspace_id, entities, opts) do
      {:ok, created} when is_list(created) ->
        meta = %{created: length(created)}

        conn
        |> put_status(:created)
        |> put_view(EntityRelationshipManager.Views.EntityJSON)
        |> render("bulk.json", entities: created, errors: [], meta: meta)

      {:ok, %{created: created, errors: errors}} ->
        formatted_errors = format_bulk_errors(errors)
        meta = %{created: length(created), failed: length(errors)}
        status = if errors != [] and created != [], do: 207, else: :created

        conn
        |> put_status(status)
        |> put_view(EntityRelationshipManager.Views.EntityJSON)
        |> render("bulk.json", entities: created, errors: formatted_errors, meta: meta)

      {:error, {:validation_errors, errors}} when mode == :atomic ->
        formatted_errors = format_bulk_errors(errors)
        meta = %{created: 0}

        conn
        |> put_status(:unprocessable_entity)
        |> json(%{error: "validation_errors", errors: formatted_errors, meta: meta})

      {:error, reason} ->
        handle_error(conn, reason)
    end
  end

  def bulk_update(conn, params) do
    workspace_id = conn.assigns.workspace_id
    updates = normalize_bulk_updates(params["entities"] || params["updates"] || [])
    mode = parse_mode(params["mode"])
    opts = [mode: mode]

    case EntityRelationshipManager.bulk_update_entities(workspace_id, updates, opts) do
      {:ok, updated} when is_list(updated) ->
        meta = %{updated: length(updated)}

        conn
        |> put_status(:ok)
        |> put_view(EntityRelationshipManager.Views.EntityJSON)
        |> render("bulk.json", entities: updated, errors: [], meta: meta)

      {:ok, %{updated: updated, errors: errors}} ->
        formatted_errors = format_bulk_errors(errors)
        meta = %{updated: length(updated), failed: length(errors)}
        status = if errors != [] and updated != [], do: 207, else: :ok

        conn
        |> put_status(status)
        |> put_view(EntityRelationshipManager.Views.EntityJSON)
        |> render("bulk.json", entities: updated, errors: formatted_errors, meta: meta)

      {:error, {:validation_errors, errors}} when mode == :atomic ->
        formatted_errors = format_bulk_errors(errors)
        meta = %{updated: 0}

        conn
        |> put_status(:unprocessable_entity)
        |> json(%{error: "validation_errors", errors: formatted_errors, meta: meta})

      {:error, reason} ->
        handle_error(conn, reason)
    end
  end

  def bulk_delete(conn, params) do
    workspace_id = conn.assigns.workspace_id
    entity_ids = params["ids"] || params["entity_ids"] || []
    opts = [mode: parse_mode(params["mode"])]

    conn
    |> do_bulk_delete(workspace_id, entity_ids, opts)
  end

  defp do_bulk_delete(conn, workspace_id, entity_ids, opts) do
    case EntityRelationshipManager.bulk_delete_entities(workspace_id, entity_ids, opts) do
      {:ok, count} when is_integer(count) ->
        render_bulk_delete(conn, :ok, count, [])

      {:ok, %{deleted_count: count, errors: errors}} ->
        status = if errors != [] and count > 0, do: 207, else: :ok
        render_bulk_delete(conn, status, count, errors)

      {:error, {:validation_errors, errors}} ->
        formatted_errors = format_bulk_errors(errors)

        conn
        |> put_status(:unprocessable_entity)
        |> json(%{error: "validation_errors", errors: formatted_errors, meta: %{deleted: 0}})

      {:error, :empty_batch} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{error: "empty_ids", message: "ids array must not be empty"})

      {:error, reason} ->
        handle_error(conn, reason)
    end
  end

  defp render_bulk_delete(conn, status, count, errors) do
    formatted_errors = format_bulk_errors(errors)
    meta = %{deleted: count, failed: length(errors)}

    conn
    |> put_status(status)
    |> put_view(EntityRelationshipManager.Views.EntityJSON)
    |> render("bulk_delete.json", deleted_count: count, errors: formatted_errors, meta: meta)
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

  defp handle_error(conn, :schema_not_found) do
    conn
    |> put_status(:unprocessable_entity)
    |> json(%{
      error: "no_schema_configured",
      message: "No schema has been configured for this workspace"
    })
  end

  defp handle_error(conn, {:validation_errors, errors}) do
    conn
    |> put_status(:unprocessable_entity)
    |> json(%{error: "validation_errors", errors: errors})
  end

  # Plain list of validation errors from SchemaValidationPolicy (single creates/updates)
  defp handle_error(conn, errors) when is_list(errors) do
    conn
    |> put_status(:unprocessable_entity)
    |> json(%{error: "validation_errors", errors: errors})
  end

  # Plain string error from SchemaValidationPolicy (e.g., "entity type 'X' is not defined...")
  defp handle_error(conn, reason) when is_binary(reason) do
    conn
    |> put_status(:unprocessable_entity)
    |> json(%{error: "validation_errors", errors: [%{message: reason}]})
  end

  defp handle_error(conn, :empty_batch) do
    conn
    |> put_status(:unprocessable_entity)
    |> json(%{error: "empty_entities", message: "entities array must not be empty"})
  end

  defp handle_error(conn, :batch_too_large) do
    conn
    |> put_status(:bad_request)
    |> json(%{error: "bad_request", message: "Batch size exceeds maximum of 1000"})
  end

  defp handle_error(conn, :not_found) do
    conn
    |> put_status(:not_found)
    |> json(%{error: "not_found"})
  end

  defp handle_error(conn, _reason) do
    conn
    |> put_status(:unprocessable_entity)
    |> put_view(EntityRelationshipManager.Views.ErrorJSON)
    |> render("422.json")
  end

  @max_limit 500

  defp validate_pagination(filters) do
    limit = Map.get(filters, :limit)
    offset = Map.get(filters, :offset)

    cond do
      limit != nil and limit < 0 ->
        {:error, "limit must be a non-negative integer"}

      limit != nil and limit > @max_limit ->
        {:error, "limit must not exceed #{@max_limit}"}

      offset != nil and offset < 0 ->
        {:error, "offset must be a non-negative integer"}

      true ->
        :ok
    end
  end

  defp validate_uuid(id, field_name) do
    case Ecto.UUID.cast(id) do
      {:ok, _} -> :ok
      :error -> {:error, "#{field_name} must be a valid UUID"}
    end
  end

  defp parse_mode("partial"), do: :partial
  defp parse_mode(_), do: :atomic

  defp format_bulk_errors(errors) when is_list(errors) do
    Enum.map(errors, fn
      %{index: index, reason: {:validation_errors, validation_errors}} ->
        %{index: index, errors: validation_errors}

      %{index: index, reason: reason} when is_list(reason) ->
        %{index: index, errors: reason}

      %{index: index, reason: reason} when is_atom(reason) ->
        %{index: index, errors: [%{message: to_string(reason)}]}

      %{index: index} = error ->
        field = Map.get(error, :field, nil)
        message = Map.get(error, :message, "Validation error")
        base = %{index: index, errors: [%{message: message}]}
        if field, do: put_in(base, [:errors, Access.at(0), :field], field), else: base

      other ->
        other
    end)
  end

  defp format_bulk_errors(errors), do: errors
end
