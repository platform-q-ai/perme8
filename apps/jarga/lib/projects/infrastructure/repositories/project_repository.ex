defmodule Jarga.Projects.Infrastructure.Repositories.ProjectRepository do
  @moduledoc """
  Repository for project data access.

  This module is part of the infrastructure layer and handles all
  database queries related to projects.

  Following Infrastructure Layer principles:
  - Encapsulates data access logic
  - Uses Ecto and Repo for database operations
  - Converts between schemas and domain entities
  - No business rules - just data retrieval and persistence
  """

  import Ecto.Query, warn: false

  alias Jarga.Repo
  alias Jarga.Projects.Domain.Entities.Project
  alias Jarga.Projects.Infrastructure.Schemas.ProjectSchema

  alias Jarga.Projects.Infrastructure.Queries.Queries

  @doc """
  Finds a project by name within a workspace.
  """
  def get_by_name(workspace_id, project_name, repo \\ Repo) do
    case Queries.find_by_name(workspace_id, project_name) |> repo.one() do
      nil -> nil
      schema -> to_domain(schema)
    end
  end

  @doc """
  Gets a project by ID.
  """
  def get(id, repo \\ Repo) do
    case repo.get(ProjectSchema, id) do
      nil -> nil
      schema -> to_domain(schema)
    end
  end

  @doc """
  Inserts a new project into the database.

  Takes domain entity attributes and returns a domain entity.
  """
  def insert(attrs, repo \\ Repo) do
    %ProjectSchema{}
    |> ProjectSchema.changeset(attrs)
    |> repo.insert()
    |> case do
      {:ok, schema} -> {:ok, to_domain(schema)}
      {:error, changeset} -> {:error, changeset}
    end
  end

  @doc """
  Updates an existing project in the database.

  Takes a schema struct (from database) and attributes, returns domain entity.
  """
  def update(project_schema, attrs, repo \\ Repo) do
    project_schema
    |> ProjectSchema.changeset(attrs)
    |> repo.update()
    |> case do
      {:ok, schema} -> {:ok, to_domain(schema)}
      {:error, changeset} -> {:error, changeset}
    end
  end

  @doc """
  Deletes a project from the database.

  Takes a schema struct (from database), returns domain entity.
  """
  def delete(project_schema, repo \\ Repo) do
    project_schema
    |> repo.delete()
    |> case do
      {:ok, schema} -> {:ok, to_domain(schema)}
      {:error, changeset} -> {:error, changeset}
    end
  end

  @doc """
  Checks if a project slug already exists within a workspace.

  ## Examples

      iex> slug_exists_in_workspace?("my-project", workspace_id, nil)
      true

      iex> slug_exists_in_workspace?("new-slug", workspace_id, nil)
      false

  """
  def slug_exists_in_workspace?(slug, workspace_id, excluding_id \\ nil, repo \\ Repo) do
    query =
      from(p in ProjectSchema,
        where: p.slug == ^slug and p.workspace_id == ^workspace_id
      )

    query =
      if excluding_id do
        from(p in query, where: p.id != ^excluding_id)
      else
        query
      end

    repo.exists?(query)
  end

  @doc """
  Converts a ProjectSchema to a domain Project entity.
  """
  def to_domain(%ProjectSchema{} = schema) do
    %Project{
      id: schema.id,
      name: schema.name,
      slug: schema.slug,
      description: schema.description,
      color: schema.color,
      is_default: schema.is_default,
      is_archived: schema.is_archived,
      user_id: schema.user_id,
      workspace_id: schema.workspace_id,
      inserted_at: schema.inserted_at,
      updated_at: schema.updated_at
    }
  end

  @doc """
  Converts a domain Project entity to a ProjectSchema.
  This is typically used for updates where you already have the schema from the DB.
  """
  def to_schema(%Project{} = project) do
    %ProjectSchema{
      id: project.id,
      name: project.name,
      slug: project.slug,
      description: project.description,
      color: project.color,
      is_default: project.is_default,
      is_archived: project.is_archived,
      user_id: project.user_id,
      workspace_id: project.workspace_id,
      inserted_at: project.inserted_at,
      updated_at: project.updated_at
    }
  end
end
