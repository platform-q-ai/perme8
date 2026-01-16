defmodule Jarga.Workspaces.Infrastructure.Schemas.WorkspaceSchema do
  @moduledoc """
  Ecto schema for workspaces.

  This is the infrastructure representation that handles database persistence.
  For the pure domain entity, see Jarga.Workspaces.Domain.Entities.Workspace.
  """

  use Ecto.Schema
  import Ecto.Changeset

  alias Jarga.Workspaces.Domain.Entities.Workspace

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "workspaces" do
    field(:name, :string)
    field(:slug, :string)
    field(:description, :string)
    field(:color, :string)
    field(:is_archived, :boolean, default: false)

    has_many(:workspace_members, Jarga.Workspaces.Infrastructure.Schemas.WorkspaceMemberSchema,
      foreign_key: :workspace_id
    )

    timestamps(type: :utc_datetime)
  end

  @doc """
  Converts a domain entity to a schema struct.
  If already a schema, returns it unchanged.
  """
  def to_schema(%__MODULE__{} = schema), do: schema

  def to_schema(%Workspace{} = workspace) do
    %__MODULE__{
      id: workspace.id,
      name: workspace.name,
      slug: workspace.slug,
      description: workspace.description,
      color: workspace.color,
      is_archived: workspace.is_archived,
      inserted_at: workspace.inserted_at,
      updated_at: workspace.updated_at
    }
  end

  @doc """
  Changeset for creating/updating workspaces.
  Accepts either a schema struct or a domain entity (which will be converted).
  """
  def changeset(workspace_or_schema, attrs)

  def changeset(%Workspace{} = workspace, attrs) do
    workspace
    |> to_schema()
    |> changeset(attrs)
  end

  def changeset(%__MODULE__{} = schema, attrs) do
    schema
    |> cast(attrs, [:name, :slug, :description, :color, :is_archived])
    |> validate_required([:name, :slug])
    |> validate_length(:name, min: 1)
    |> unique_constraint(:slug)
  end
end
