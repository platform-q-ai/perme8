defmodule Jarga.Workspaces.Workspace do
  @moduledoc """
  Schema for workspaces that organize projects and team members.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "workspaces" do
    field(:name, :string)
    field(:slug, :string)
    field(:description, :string)
    field(:color, :string)
    field(:is_archived, :boolean, default: false)

    has_many(:workspace_members, Jarga.Workspaces.WorkspaceMember)

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(workspace, attrs) do
    workspace
    |> cast(attrs, [:name, :slug, :description, :color, :is_archived])
    |> validate_required([:name, :slug])
    |> validate_length(:name, min: 1)
    |> unique_constraint(:slug)
  end
end
