defmodule JargaApi.ProjectApiController do
  @moduledoc """
  Controller for Project API endpoints.

  Handles REST API requests for project data using API key authentication.
  All endpoints require Bearer token authentication via ApiAuthPlug.

  The API key acts as its owner (user), so the same authorization rules apply
  as if the user were accessing the data directly. The workspace_access list
  on the API key restricts which workspaces can be accessed.

  ## Endpoints

    * `POST /api/workspaces/:workspace_slug/projects` - Create a project
    * `GET /api/workspaces/:workspace_slug/projects/:slug` - Get project details with documents

  """

  use JargaApi, :controller

  alias JargaApi.Accounts
  alias Jarga.Projects
  alias Jarga.Documents
  alias Jarga.Workspaces

  @doc """
  Creates a new project in a workspace.

  The API key must have access to the workspace, and the user must have
  permission to create projects (member, admin, or owner role).

  ## Request Body

    * `name` - Required. Name of the project
    * `description` - Optional. Description of the project

  ## Responses

    * 201 - Project created successfully
    * 401 - Invalid or revoked API key
    * 403 - API key lacks workspace access or user lacks permission
    * 422 - Validation error

  """
  def create(conn, %{"workspace_slug" => workspace_slug} = params) do
    user = conn.assigns.current_user
    api_key = conn.assigns.api_key

    opts = [
      get_workspace_and_member_by_slug: &Workspaces.get_workspace_and_member_by_slug/2,
      create_project: &Projects.create_project/3
    ]

    project_attrs = Map.take(params, ["name", "description"])

    case Accounts.create_project_via_api(user, api_key, workspace_slug, project_attrs, opts) do
      {:ok, project} ->
        conn
        |> put_status(:created)
        |> render(:show, project: project, workspace_slug: workspace_slug)

      {:error, %Ecto.Changeset{} = changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> render(:validation_error, changeset: changeset)

      {:error, :workspace_not_found} ->
        conn
        |> put_status(:not_found)
        |> render(:error, message: "Workspace not found")

      {:error, reason} when reason in [:forbidden, :unauthorized] ->
        conn
        |> put_status(:forbidden)
        |> render(:error, message: "Insufficient permissions")
    end
  end

  @doc """
  Gets a project with its documents.

  The API key must have access to the workspace.

  ## Responses

    * 200 - Project found
    * 401 - Invalid or revoked API key
    * 403 - API key lacks workspace access
    * 404 - Project not found

  """
  def show(conn, %{"workspace_slug" => workspace_slug, "slug" => project_slug}) do
    user = conn.assigns.current_user
    api_key = conn.assigns.api_key

    opts = [
      get_workspace_and_member_by_slug: &Workspaces.get_workspace_and_member_by_slug/2,
      get_project_by_slug: &Projects.get_project_by_slug/3,
      list_documents_for_project: &Documents.list_documents_for_project/3
    ]

    case Accounts.get_project_with_documents_via_api(
           user,
           api_key,
           workspace_slug,
           project_slug,
           opts
         ) do
      {:ok, project_data} ->
        conn
        |> put_status(:ok)
        |> render(:show_with_documents,
          project: project_data.project,
          workspace_slug: workspace_slug,
          documents: project_data.documents
        )

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
end
