defmodule EntityRelationshipManager.SchemaController do
  use EntityRelationshipManager, :controller

  alias EntityRelationshipManager.Plugs.AuthorizePlug

  plug(AuthorizePlug, [action: :read_schema] when action in [:show])
  plug(AuthorizePlug, [action: :write_schema] when action in [:update])

  def show(conn, _params) do
    workspace_id = conn.assigns.workspace_id

    case EntityRelationshipManager.get_schema(workspace_id) do
      {:ok, schema} ->
        conn
        |> put_status(:ok)
        |> put_view(EntityRelationshipManager.Views.SchemaJSON)
        |> render("show.json", schema: schema)

      {:error, :not_found} ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "schema_not_found", message: "No schema defined for this workspace"})
    end
  end

  def update(conn, params) do
    workspace_id = conn.assigns.workspace_id

    attrs = %{
      entity_types: params["entity_types"] || [],
      edge_types: params["edge_types"] || [],
      version: params["version"]
    }

    case EntityRelationshipManager.upsert_schema(workspace_id, attrs) do
      {:ok, schema} ->
        conn
        |> put_status(:ok)
        |> put_view(EntityRelationshipManager.Views.SchemaJSON)
        |> render("show.json", schema: schema)

      {:error, :stale} ->
        conn
        |> put_status(:conflict)
        |> json(%{
          error: "version_conflict",
          message: "Schema has been modified by a concurrent update; please reload and retry"
        })

      {:error, %Ecto.Changeset{} = changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> put_view(EntityRelationshipManager.Views.ErrorJSON)
        |> render("422.json", changeset: changeset)

      {:error, errors} when is_list(errors) ->
        structured_errors =
          Enum.map(errors, fn
            error when is_binary(error) -> %{message: error}
            %{} = error -> error
          end)

        conn
        |> put_status(:unprocessable_entity)
        |> json(%{error: "validation_errors", errors: structured_errors})

      {:error, _reason} ->
        conn
        |> put_status(:unprocessable_entity)
        |> put_view(EntityRelationshipManager.Views.ErrorJSON)
        |> render("422.json")
    end
  end
end
