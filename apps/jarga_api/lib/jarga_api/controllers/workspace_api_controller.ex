defmodule JargaApi.WorkspaceApiController do
  @moduledoc """
  Controller for Workspace API endpoints.

  Handles REST API requests for workspace data using API key authentication.
  All endpoints require Bearer token authentication via ApiAuthPlug.

  The API key acts as its owner (user), so the same authorization rules apply
  as if the user were accessing the data directly. The workspace_access list
  on the API key further restricts which workspaces can be accessed.

  ## Endpoints

    * `GET /api/workspaces` - List workspaces accessible to the API key
    * `GET /api/workspaces/:slug` - Get workspace details with documents and projects

  """

  use JargaApi, :controller

  alias JargaApi.Accounts
  alias Jarga.Workspaces
  alias Jarga.Documents
  alias Jarga.Projects

  @doc """
  Lists all workspaces accessible to the authenticated API key.

  Returns a JSON response with basic workspace info (id, name, slug).
  Does not include documents or projects in the list response.

  The list is filtered to only include workspaces that:
  1. The user (API key owner) has access to
  2. The API key's workspace_access list includes
  """
  def index(conn, _params) do
    user = conn.assigns.current_user
    api_key = conn.assigns.api_key

    opts = [
      list_workspaces_for_user: &Workspaces.list_workspaces_for_user/1
    ]

    {:ok, workspaces} = Accounts.list_accessible_workspaces(user, api_key, opts)

    render(conn, :index, workspaces: workspaces)
  end

  @doc """
  Gets a single workspace with documents and projects.

  Returns a JSON response with workspace details including:
  - Basic info: id, name, slug
  - documents: list of documents viewable by user (own + public from others)
  - projects: list of projects the user has access to

  ## Error Responses

  - 403 Forbidden: API key lacks access to the workspace
  - 404 Not Found: Workspace doesn't exist or user has no access
  """
  def show(conn, %{"slug" => slug}) do
    user = conn.assigns.current_user
    api_key = conn.assigns.api_key

    opts = [
      get_workspace_by_slug: &Workspaces.get_workspace_by_slug/2,
      list_documents_for_workspace: &Documents.list_documents_for_workspace/2,
      list_projects_for_workspace: &Projects.list_projects_for_workspace/2
    ]

    case Accounts.get_workspace_with_details(user, api_key, slug, opts) do
      {:ok, workspace_data} ->
        render(conn, :show, workspace: workspace_data)

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
end
