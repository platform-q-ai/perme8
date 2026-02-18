defmodule Agents.Infrastructure.Gateways.JargaGateway do
  @moduledoc """
  Thin adapter implementing JargaGatewayBehaviour by delegating to the
  Identity and Jarga context facades in-process.

  Each function resolves the user from their ID via Identity, then delegates
  to the appropriate Jarga or Identity context function.
  """

  # Identity and Jarga are sibling umbrella apps that cannot be listed as
  # compile-time dependencies. The modules are available at runtime.
  @compile {:no_warn_undefined, [Identity, Jarga.Projects, Jarga.Documents]}

  @behaviour Agents.Application.Behaviours.JargaGatewayBehaviour

  @impl true
  def list_workspaces(user_id) do
    with {:ok, user} <- resolve_user(user_id) do
      {:ok, Identity.list_workspaces_for_user(user)}
    end
  end

  @impl true
  def get_workspace(user_id, workspace_slug) do
    with {:ok, user} <- resolve_user(user_id) do
      Identity.get_workspace_by_slug(user, workspace_slug)
    end
  end

  @impl true
  def list_projects(user_id, workspace_id) do
    with {:ok, user} <- resolve_user(user_id) do
      {:ok, Jarga.Projects.list_projects_for_workspace(user, workspace_id)}
    end
  end

  @impl true
  def create_project(user_id, workspace_id, attrs) do
    with {:ok, user} <- resolve_user(user_id) do
      Jarga.Projects.create_project(user, workspace_id, attrs)
    end
  end

  @impl true
  def get_project(user_id, workspace_id, slug) do
    with {:ok, user} <- resolve_user(user_id) do
      Jarga.Projects.get_project_by_slug(user, workspace_id, slug)
    end
  end

  @impl true
  def list_documents(user_id, workspace_id, opts \\ []) do
    with {:ok, user} <- resolve_user(user_id) do
      case Keyword.get(opts, :project_id) do
        nil ->
          {:ok, Jarga.Documents.list_documents_for_workspace(user, workspace_id)}

        project_id ->
          {:ok, Jarga.Documents.list_documents_for_project(user, workspace_id, project_id)}
      end
    end
  end

  @impl true
  def create_document(user_id, workspace_id, attrs) do
    with {:ok, user} <- resolve_user(user_id) do
      Jarga.Documents.create_document(user, workspace_id, attrs)
    end
  end

  @impl true
  def get_document(user_id, workspace_id, slug) do
    with {:ok, user} <- resolve_user(user_id) do
      Jarga.Documents.get_document_by_slug(user, workspace_id, slug)
    end
  end

  defp resolve_user(user_id) do
    case Identity.get_user(user_id) do
      nil -> {:error, :user_not_found}
      user -> {:ok, user}
    end
  end
end
