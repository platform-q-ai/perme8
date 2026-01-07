defmodule JargaWeb.ProjectApiJSON do
  @moduledoc """
  JSON rendering for Project API endpoints.
  """

  @doc """
  Renders a created project (without documents).
  """
  def show(%{project: project, workspace_slug: workspace_slug}) do
    %{data: project_data(project, workspace_slug)}
  end

  @doc """
  Renders a project with its documents.
  """
  def show_with_documents(%{
        project: project,
        workspace_slug: workspace_slug,
        documents: documents
      }) do
    %{
      data:
        project
        |> project_data(workspace_slug)
        |> Map.put(:documents, Enum.map(documents, &document_basic/1))
    }
  end

  @doc """
  Renders a validation error.
  """
  def validation_error(%{changeset: changeset}) do
    errors =
      Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
        Regex.replace(~r"%{(\w+)}", msg, fn _, key ->
          opts |> Keyword.get(String.to_existing_atom(key), key) |> to_string()
        end)
      end)

    %{errors: errors}
  end

  @doc """
  Renders an error message.
  """
  def error(%{message: message}) do
    %{error: message}
  end

  defp project_data(project, workspace_slug) do
    %{
      name: project.name,
      slug: project.slug,
      description: project.description,
      workspace_slug: workspace_slug
    }
  end

  defp document_basic(document) do
    %{
      title: document.title,
      slug: document.slug
    }
  end
end
