defmodule Jarga.Documents.Infrastructure.Repositories.DocumentRepository do
  @moduledoc """
  Infrastructure layer for Document data access.
  Provides database query functions for documents.

  This module encapsulates all database operations for documents,
  following the Repository pattern to keep infrastructure concerns
  separate from application logic.

  This repository converts between infrastructure schemas (DocumentSchema)
  and pure domain entities (Document).
  """

  @behaviour Jarga.Documents.Application.Behaviours.DocumentRepositoryBehaviour

  import Ecto.Query
  alias Identity.Repo, as: Repo
  alias Jarga.Documents.Infrastructure.Schemas.DocumentSchema
  alias Jarga.Documents.Domain.Entities.Document
  alias Jarga.Documents.Infrastructure.Queries.DocumentQueries

  @doc """
  Updates an existing document in the database.
  """
  def update(schema_or_id, attrs) do
    schema =
      case schema_or_id do
        %DocumentSchema{} = s -> s
        id when is_binary(id) -> Repo.get(DocumentSchema, id)
      end

    if schema do
      schema
      |> DocumentSchema.changeset(attrs)
      |> Repo.update()
      |> case do
        {:ok, schema} -> {:ok, Document.from_schema(schema)}
        {:error, changeset} -> {:error, changeset}
      end
    else
      {:error, :not_found}
    end
  end

  @doc """
  Gets a document by ID with components preloaded.
  """
  def get_by_id_with_components(document_id) do
    schema =
      DocumentQueries.base()
      |> DocumentQueries.by_id(document_id)
      |> Repo.one()
      |> Repo.preload(:document_components)

    case schema do
      nil -> nil
      schema -> Document.from_schema(schema)
    end
  end

  @doc """
  Gets a document by ID with project preloaded.
  """
  def get_by_id_with_project(document_id) do
    schema =
      DocumentQueries.base()
      |> DocumentQueries.by_id(document_id)
      |> Repo.one()
      |> Repo.preload(:project)

    case schema do
      nil -> nil
      schema -> Document.from_schema(schema)
    end
  end

  @doc """
  Lists all documents belonging to a project.
  """
  def list_by_project_id(project_id) do
    DocumentSchema
    |> where([d], d.project_id == ^project_id)
    |> Repo.all()
    |> Enum.map(&Document.from_schema/1)
  end

  @doc """
  Gets a document by title.
  """
  def get_by_title(title) do
    schema =
      DocumentSchema
      |> where([d], d.title == ^title)
      |> Repo.one()

    case schema do
      nil -> nil
      schema -> Document.from_schema(schema)
    end
  end

  @doc """
  Gets a document by ID.

  Returns the document domain entity if found, nil otherwise.

  ## Examples

      iex> get_by_id("existing-id")
      %Document{}

      iex> get_by_id("non-existent-id")
      nil

  """
  def get_by_id(document_id) do
    schema =
      DocumentQueries.base()
      |> DocumentQueries.by_id(document_id)
      |> Repo.one()

    case schema do
      nil -> nil
      schema -> Document.from_schema(schema)
    end
  end

  @doc """
  Checks if a slug already exists within a workspace, optionally excluding a specific document.

  Used by SlugGenerator to ensure uniqueness.
  """
  @impl true
  def slug_exists_in_workspace?(slug, workspace_id, excluding_id \\ nil) do
    query =
      from(d in DocumentSchema,
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

  @doc """
  Inserts a document changeset using Repo.insert.

  This function is meant to be used inside Ecto.Multi.run callbacks.
  Returns a domain entity on success.

  ## Parameters

  - `changeset` - The document changeset to insert

  ## Returns

  - `{:ok, document}` - Insert succeeded (returns domain entity)
  - `{:error, changeset}` - Insert failed
  """
  @impl true
  def insert(changeset) do
    case Repo.insert(changeset) do
      {:ok, schema} -> {:ok, Document.from_schema(schema)}
      {:error, changeset} -> {:error, changeset}
    end
  end

  @doc """
  Inserts a document component changeset using Repo.insert.

  This function is meant to be used inside Ecto.Multi.run callbacks.

  ## Parameters

  - `changeset` - The document component changeset to insert

  ## Returns

  - `{:ok, document_component}` - Insert succeeded
  - `{:error, changeset}` - Insert failed
  """
  @impl true
  def insert_component(changeset) do
    Repo.insert(changeset)
  end

  @doc """
  Updates a document within a transaction.
  Returns a domain entity on success.

  ## Parameters

  - `changeset` - The document changeset to update

  ## Returns

  - `{:ok, updated_document}` - Update succeeded (returns domain entity)
  - `{:error, changeset}` - Update failed
  """
  def update_in_transaction(changeset) do
    Repo.transaction(fn ->
      case Repo.update(changeset) do
        {:ok, schema} -> Document.from_schema(schema)
        {:error, changeset} -> Repo.rollback(changeset)
      end
    end)
  end

  @doc """
  Deletes a document within a transaction.
  Accepts either a domain entity or schema, returns a domain entity on success.

  ## Parameters

  - `document` - The document domain entity or schema to delete

  ## Returns

  - `{:ok, deleted_document}` - Delete succeeded (returns domain entity)
  - `{:error, changeset}` - Delete failed
  """
  def delete_in_transaction(%Document{} = document) do
    # Convert domain entity to schema for deletion
    schema = Repo.get(DocumentSchema, document.id)
    delete_in_transaction(schema)
  end

  def delete_in_transaction(%DocumentSchema{} = schema) do
    Repo.transaction(fn ->
      case Repo.delete(schema) do
        {:ok, deleted_schema} -> Document.from_schema(deleted_schema)
        {:error, changeset} -> Repo.rollback(changeset)
      end
    end)
  end

  @doc """
  Executes an Ecto.Multi transaction.

  ## Parameters

  - `multi` - The Ecto.Multi struct to execute

  ## Returns

  - `{:ok, changes_map}` - Transaction succeeded
  - `{:error, failed_operation, failed_value, changes_so_far}` - Transaction failed
  """
  @impl true
  def transaction(multi) do
    Repo.transaction(multi)
  end
end
