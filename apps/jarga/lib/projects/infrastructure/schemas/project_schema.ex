defmodule Jarga.Projects.Infrastructure.Schemas.ProjectSchema do
  @moduledoc """
  Ecto schema for projects.

  This module is part of the infrastructure layer and handles
  database mapping for projects.

  Following Infrastructure Layer principles:
  - Contains Ecto schema definition
  - Handles database persistence concerns
  - Provides changesets for validation
  - Maps to/from domain entities
  """

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "projects" do
    field(:name, :string)
    field(:slug, :string)
    field(:description, :string)
    field(:color, :string)
    field(:is_default, :boolean, default: false)
    field(:is_archived, :boolean, default: false)

    belongs_to(:user, Jarga.Accounts.Infrastructure.Schemas.UserSchema)
    belongs_to(:workspace, Jarga.Workspaces.Infrastructure.Schemas.WorkspaceSchema)

    timestamps(type: :utc_datetime)
  end

  @doc """
  Changeset for creating or updating a project.
  """
  def changeset(project, attrs) do
    project
    |> cast(attrs, [
      :name,
      :slug,
      :description,
      :color,
      :is_default,
      :is_archived,
      :user_id,
      :workspace_id
    ])
    |> validate_required([:name, :slug, :user_id, :workspace_id])
    |> validate_length(:name, min: 1)
    |> unique_constraint(:slug, name: :projects_workspace_id_slug_index)
    |> foreign_key_constraint(:user_id)
    |> foreign_key_constraint(:workspace_id)
  end
end
