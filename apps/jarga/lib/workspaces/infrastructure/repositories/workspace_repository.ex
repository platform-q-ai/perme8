defmodule Jarga.Workspaces.Infrastructure.Repositories.WorkspaceRepository do
  @moduledoc """
  Repository for Workspace data access operations.

  Provides a clean abstraction over database operations for Workspace entities.
  Converts between WorkspaceSchema (infrastructure) and Workspace (domain).
  """

  alias Jarga.Workspaces.Domain.Entities.Workspace
  alias Jarga.Workspaces.Infrastructure.Schemas.WorkspaceSchema
  alias Jarga.Repo

  @doc """
  Gets a workspace by ID.
  Returns domain entity if found, nil otherwise.
  """
  def get_by_id(id, repo \\ Repo) do
    case repo.get(WorkspaceSchema, id) do
      nil -> nil
      schema -> Workspace.from_schema(schema)
    end
  end

  @doc """
  Creates a new workspace from attributes.
  Returns {:ok, workspace_entity} if successful, {:error, changeset} otherwise.
  """
  def insert(attrs, repo \\ Repo) when is_map(attrs) do
    case %WorkspaceSchema{}
         |> WorkspaceSchema.changeset(attrs)
         |> repo.insert() do
      {:ok, schema} -> {:ok, Workspace.from_schema(schema)}
      {:error, changeset} -> {:error, changeset}
    end
  end

  @doc """
  Updates an existing workspace.
  Accepts either domain entity or schema.
  Returns {:ok, workspace_entity} if successful, {:error, changeset} otherwise.
  """
  def update(workspace_or_schema, attrs, repo \\ Repo)

  def update(%Workspace{} = workspace, attrs, repo) when is_map(attrs) do
    workspace
    |> WorkspaceSchema.to_schema()
    |> update(attrs, repo)
  end

  def update(%WorkspaceSchema{} = schema, attrs, repo) when is_map(attrs) do
    case schema
         |> WorkspaceSchema.changeset(attrs)
         |> repo.update() do
      {:ok, schema} -> {:ok, Workspace.from_schema(schema)}
      {:error, changeset} -> {:error, changeset}
    end
  end

  @doc """
  Inserts a workspace using a changeset.
  Low-level function for use cases needing custom changesets.
  """
  def insert_changeset(%Ecto.Changeset{} = changeset, repo \\ Repo) do
    case repo.insert(changeset) do
      {:ok, schema} -> {:ok, Workspace.from_schema(schema)}
      {:error, changeset} -> {:error, changeset}
    end
  end
end
