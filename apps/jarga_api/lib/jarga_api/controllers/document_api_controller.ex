defmodule JargaApi.DocumentApiController do
  @moduledoc """
  Controller for Document API endpoints.

  Handles REST API requests for document data using API key authentication.
  All endpoints require Bearer token authentication via ApiAuthPlug.

  The API key acts as its owner (user), so the same authorization rules apply
  as if the user were accessing the data directly. The workspace_access list
  on the API key restricts which workspaces can be accessed.

  ## Endpoints

    * `POST /api/workspaces/:workspace_slug/documents` - Create a document
    * `POST /api/workspaces/:workspace_slug/projects/:project_slug/documents` - Create a document in a project
    * `GET /api/workspaces/:workspace_slug/documents/:slug` - Get document details

  """

  use JargaApi, :controller

  alias JargaApi.Accounts
  alias Jarga.Documents
  alias Jarga.Workspaces
  alias Jarga.Projects

  @doc """
  Creates a new document in a workspace, optionally within a project.

  The API key must have access to the workspace, and the user must have
  permission to create documents (member, admin, or owner role).

  ## Request Body

    * `title` - Required. Title of the document
    * `content` - Optional. Initial content for the document's note
    * `visibility` - Optional. "public" or "private" (defaults to "private")

  ## Responses

    * 201 - Document created successfully
    * 401 - Invalid or revoked API key
    * 403 - API key lacks workspace access or user lacks permission
    * 404 - Workspace or project not found
    * 422 - Validation error

  """
  def create(conn, params) do
    user = conn.assigns.current_user
    api_key = conn.assigns.api_key

    workspace_slug = params["workspace_slug"]
    project_slug = params["project_slug"]

    attrs =
      params
      |> Map.take(["title", "content", "visibility"])
      |> maybe_add_project_slug(project_slug)

    opts = [
      get_workspace_and_member_by_slug: &Workspaces.get_workspace_and_member_by_slug/2,
      create_document: &Documents.create_document/3,
      get_project_by_slug: &Projects.get_project_by_slug/3
    ]

    case Accounts.create_document_via_api(user, api_key, workspace_slug, attrs, opts) do
      {:ok, document} ->
        conn
        |> put_status(:created)
        |> render(:created,
          document: document,
          workspace_slug: workspace_slug,
          project_slug: project_slug
        )

      {:error, %Ecto.Changeset{} = changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> render(:validation_error, changeset: changeset)

      {:error, :workspace_not_found} ->
        conn
        |> put_status(:not_found)
        |> render(:error, message: "Workspace not found")

      {:error, :project_not_found} ->
        conn
        |> put_status(:not_found)
        |> render(:error, message: "Project not found")

      {:error, reason} when reason in [:forbidden, :unauthorized] ->
        conn
        |> put_status(:forbidden)
        |> render(:error, message: "Insufficient permissions")
    end
  end

  @doc """
  Gets a document by slug.

  The API key must have access to the workspace.

  ## Responses

    * 200 - Document found
    * 401 - Invalid or revoked API key
    * 403 - API key lacks workspace access
    * 404 - Document or workspace not found

  """
  def show(conn, %{"workspace_slug" => workspace_slug, "slug" => document_slug}) do
    user = conn.assigns.current_user
    api_key = conn.assigns.api_key

    opts = [
      get_workspace_and_member_by_slug: &Workspaces.get_workspace_and_member_by_slug/2,
      get_document_by_slug: &Documents.get_document_by_slug/3,
      get_document_note: &Documents.get_document_note/1,
      get_project: &Projects.get_project/3,
      get_user: &Identity.get_user/1
    ]

    case Accounts.get_document_via_api(user, api_key, workspace_slug, document_slug, opts) do
      {:ok, result} ->
        conn
        |> put_status(:ok)
        |> render(:show, document: result)

      {:error, :workspace_not_found} ->
        conn
        |> put_status(:not_found)
        |> render(:error, message: "Workspace not found")

      {:error, :document_not_found} ->
        conn
        |> put_status(:not_found)
        |> render(:error, message: "Document not found")

      {:error, reason} when reason in [:forbidden, :unauthorized] ->
        conn
        |> put_status(:forbidden)
        |> render(:error, message: "Insufficient permissions")
    end
  end

  defp maybe_add_project_slug(attrs, nil), do: attrs

  defp maybe_add_project_slug(attrs, project_slug),
    do: Map.put(attrs, "project_slug", project_slug)
end
