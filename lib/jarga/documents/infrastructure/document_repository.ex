defmodule Jarga.Documents.Infrastructure.DocumentRepository do
  @moduledoc """
  Infrastructure layer for Document data access.
  Provides database query functions for documents.
  """

  import Ecto.Query
  alias Jarga.Repo
  alias Jarga.Documents.{Document, Queries}

  @doc """
  Gets a document by ID.

  Returns the document if found, nil otherwise.

  ## Examples

      iex> get_by_id("existing-id")
      %Document{}

      iex> get_by_id("non-existent-id")
      nil

  """
  def get_by_id(document_id) do
    Queries.base()
    |> Queries.by_id(document_id)
    |> Repo.one()
  end

  @doc """
  Checks if a slug already exists within a workspace, optionally excluding a specific document.

  Used by SlugGenerator to ensure uniqueness.
  """
  def slug_exists_in_workspace?(slug, workspace_id, excluding_id \\ nil) do
    query =
      from(d in Document,
        where: d.slug == ^slug and d.workspace_id == ^workspace_id
      )

    query =
      if excluding_id do
        from(d in query, where: d.id != ^excluding_id)
      else
        query
      end

    Repo.exists?(query)
  end
end
