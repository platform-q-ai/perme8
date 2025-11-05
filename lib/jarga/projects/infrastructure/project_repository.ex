defmodule Jarga.Projects.Infrastructure.ProjectRepository do
  @moduledoc """
  Repository for project data access.

  This module is part of the infrastructure layer and handles all
  database queries related to projects.

  Following Infrastructure Layer principles:
  - Encapsulates data access logic
  - Uses Ecto and Repo for database operations
  - Returns domain entities (Project)
  - No business rules - just data retrieval
  """

  import Ecto.Query, warn: false

  alias Jarga.Repo
  alias Jarga.Projects.Project

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
      from(p in Project,
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
end
