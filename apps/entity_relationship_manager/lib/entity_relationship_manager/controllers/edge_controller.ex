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

    filter_fields = [
      {:type, :string, "type"},
      {:limit, :integer, "limit"},
      {:offset, :integer, "offset"}
    ]

    case EntityRelationshipManager.ControllerHelpers.build_filters(conn, params, filter_fields) do
      {:ok, filters} ->
        case EntityRelationshipManager.list_edges(workspace_id, filters) do
          {:ok, edges} ->
            meta = %{
              total: length(edges),
              limit: Map.get(filters, :limit, 100),
              offset: Map.get(filters, :offset, 0)
            }

            conn
            |> put_status(:ok)
            |> put_view(EntityRelationshipManager.Views.EdgeJSON)
            |> render("index.json", edges: edges, meta: meta)

          {:error, reason} ->
            handle_error(conn, reason)
        end

      {:error, conn} ->
        conn
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
        |> json(%{error: "not_found"})

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
        |> json(%{error: "not_found"})

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
        |> json(%{error: "not_found"})

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

    mode = parse_mode(params["mode"])
    do_bulk_create_edges(conn, workspace_id, edges, mode)
  end

  defp do_bulk_create_edges(conn, workspace_id, edges, mode) do
    case EntityRelationshipManager.bulk_create_edges(workspace_id, edges, mode: mode) do
      {:ok, created} when is_list(created) ->
        render_bulk_edges(conn, :created, created, [])

      {:ok, %{created: created, errors: errors}} ->
        status = bulk_create_status(created, errors)
        render_bulk_edges(conn, status, created, errors)

      {:error, {:validation_errors, errors}} when mode == :atomic ->
        formatted_errors = format_bulk_errors(errors)

        conn
        |> put_status(:unprocessable_entity)
        |> json(%{error: "validation_errors", errors: formatted_errors, meta: %{created: 0}})

      {:error, reason} ->
        handle_error(conn, reason)
    end
  end

  defp bulk_create_status([], _errors), do: :unprocessable_entity
  defp bulk_create_status(_created, []), do: :created
  defp bulk_create_status(_created, _errors), do: 207

  defp render_bulk_edges(conn, status, created, errors) do
    formatted_errors = format_bulk_errors(errors)
    meta = %{created: length(created), failed: length(errors)}

    conn
    |> put_status(status)
    |> put_view(EntityRelationshipManager.Views.EdgeJSON)
    |> render("bulk.json", edges: created, errors: formatted_errors, meta: meta)
  end

  defp handle_error(conn, :schema_not_found) do
    conn
    |> put_status(:unprocessable_entity)
    |> json(%{
      error: "no_schema_configured",
      message: "No schema has been configured for this workspace"
    })
  end

  defp handle_error(conn, :source_not_found) do
    conn
    |> put_status(:unprocessable_entity)
    |> json(%{
      error: "validation_errors",
      errors: [%{field: "source_id", message: "Source entity not found"}]
    })
  end

  defp handle_error(conn, :target_not_found) do
    conn
    |> put_status(:unprocessable_entity)
    |> json(%{
      error: "validation_errors",
      errors: [%{field: "target_id", message: "Target entity not found"}]
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

  # Plain string error from SchemaValidationPolicy (e.g., "edge type 'X' is not defined...")
  defp handle_error(conn, reason) when is_binary(reason) do
    conn
    |> put_status(:unprocessable_entity)
    |> json(%{error: "validation_errors", errors: [%{message: reason}]})
  end

  defp handle_error(conn, :empty_batch) do
    conn
    |> put_status(:unprocessable_entity)
    |> json(%{error: "empty_edges", message: "edges array must not be empty"})
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
