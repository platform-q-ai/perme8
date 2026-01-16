defmodule JargaWeb.WorkspaceApiJSON do
  @moduledoc """
  JSON rendering for Workspace API endpoints.
  """

  @doc """
  Renders a list of workspaces.
  """
  def index(%{workspaces: workspaces}) do
    %{data: Enum.map(workspaces, &workspace_basic/1)}
  end

  @doc """
  Renders a single workspace with documents and projects.
  """
  def show(%{workspace: workspace}) do
    %{data: workspace_with_details(workspace)}
  end

  @doc """
  Renders an error message.
  """
  def error(%{message: message}) do
    %{error: message}
  end

  defp workspace_basic(workspace) do
    %{
      name: workspace.name,
      slug: workspace.slug
    }
  end

  defp workspace_with_details(workspace) do
    %{
      name: workspace.name,
      slug: workspace.slug,
      documents: Enum.map(workspace.documents, &document_basic/1),
      projects: Enum.map(workspace.projects, &project_basic/1)
    }
  end

  defp document_basic(document) do
    %{
      title: document.title,
      slug: document.slug
    }
  end

  defp project_basic(project) do
    %{
      name: project.name,
      slug: project.slug
    }
  end
end
