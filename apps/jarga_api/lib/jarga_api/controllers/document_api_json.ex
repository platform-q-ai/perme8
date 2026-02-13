defmodule JargaApi.DocumentApiJSON do
  @moduledoc """
  JSON rendering for Document API endpoints.
  """

  alias Jarga.Documents.Notes.Domain.ContentHash

  @doc """
  Renders a document retrieved via the API (GET response).

  Takes a result map from GetDocumentViaApi use case with keys:
  title, slug, content, visibility, owner, workspace_slug, project_slug.
  Includes content_hash computed from the document's content.
  Omits project_slug if nil.
  """
  def show(%{document: result}) do
    %{data: document_data_with_hash(result)}
  end

  @doc """
  Renders a created document (POST response).

  Takes the domain document struct and workspace/project context.
  Translates is_public to visibility string. Includes content_hash.
  """
  def created(%{
        document: document,
        workspace_slug: workspace_slug,
        project_slug: project_slug,
        owner_email: owner_email
      }) do
    # For created documents, content may not be in the document struct directly.
    # Compute content_hash from whatever content was provided (nil produces a stable hash).
    content = Map.get(document, :content)
    content_hash = ContentHash.compute(content)

    data = %{
      title: document.title,
      slug: document.slug,
      visibility: if(document.is_public, do: "public", else: "private"),
      owner: owner_email,
      workspace_slug: workspace_slug,
      content_hash: content_hash
    }

    data = maybe_add_project_slug(data, project_slug)

    %{data: data}
  end

  @doc """
  Renders an updated document (PATCH response).

  Takes a result map from UpdateDocumentViaApi use case which already
  includes content_hash. Uses the same shape as show/1 for consistency.
  """
  def updated(%{document: result}) do
    data = %{
      title: result.title,
      slug: result.slug,
      content: result.content,
      content_hash: result.content_hash,
      visibility: result.visibility,
      owner: result.owner,
      workspace_slug: result.workspace_slug
    }

    data = maybe_add_project_slug(data, result.project_slug)

    %{data: data}
  end

  @doc """
  Renders a content conflict response (409 Conflict).

  Returns the current server-side content and its hash so the client
  can re-base their changes.
  """
  def content_conflict(%{conflict_data: conflict_data}) do
    %{
      error: "content_conflict",
      message:
        "Content has been modified since your last read. Re-base your changes from the returned content.",
      data: %{
        content: conflict_data.content,
        content_hash: conflict_data.content_hash
      }
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

  defp document_data_with_hash(result) do
    content_hash =
      case Map.get(result, :content_hash) do
        nil -> ContentHash.compute(result.content)
        hash -> hash
      end

    data = %{
      title: result.title,
      slug: result.slug,
      content: result.content,
      content_hash: content_hash,
      visibility: result.visibility,
      owner: result.owner,
      workspace_slug: result.workspace_slug
    }

    maybe_add_project_slug(data, result.project_slug)
  end

  defp maybe_add_project_slug(data, nil), do: data
  defp maybe_add_project_slug(data, project_slug), do: Map.put(data, :project_slug, project_slug)
end
