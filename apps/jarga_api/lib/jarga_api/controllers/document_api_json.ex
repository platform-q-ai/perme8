defmodule JargaApi.DocumentApiJSON do
  @moduledoc """
  JSON rendering for Document API endpoints.
  """

  @doc """
  Renders a document retrieved via the API (GET response).

  Takes a result map from GetDocumentViaApi use case with keys:
  title, slug, content, visibility, owner, workspace_slug, project_slug.
  Omits project_slug if nil.
  """
  def show(%{document: result}) do
    %{data: document_data(result)}
  end

  @doc """
  Renders a created document (POST response).

  Takes the domain document struct and workspace/project context.
  Translates is_public to visibility string.
  """
  def created(%{
        document: document,
        workspace_slug: workspace_slug,
        project_slug: project_slug,
        owner_email: owner_email
      }) do
    data = %{
      title: document.title,
      slug: document.slug,
      visibility: if(document.is_public, do: "public", else: "private"),
      owner: owner_email,
      workspace_slug: workspace_slug
    }

    data = maybe_add_project_slug(data, project_slug)

    %{data: data}
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

  defp document_data(result) do
    data = %{
      title: result.title,
      slug: result.slug,
      content: result.content,
      visibility: result.visibility,
      owner: result.owner,
      workspace_slug: result.workspace_slug
    }

    maybe_add_project_slug(data, result.project_slug)
  end

  defp maybe_add_project_slug(data, nil), do: data
  defp maybe_add_project_slug(data, project_slug), do: Map.put(data, :project_slug, project_slug)
end
