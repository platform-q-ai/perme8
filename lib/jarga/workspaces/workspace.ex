defmodule Jarga.Workspaces.Workspace do
  @moduledoc """
  Schema for workspaces that organize projects and team members.
  """

  use Ecto.Schema
  import Ecto.Changeset

  alias Jarga.Workspaces.Domain.SlugGenerator
  alias Jarga.Workspaces.Infrastructure.MembershipRepository

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
    |> cast(attrs, [:name, :description, :color, :is_archived])
    |> validate_required([:name])
    |> validate_length(:name, min: 1)
    |> generate_slug()
    |> validate_required([:slug])
    |> unique_constraint(:slug)
  end

  defp generate_slug(changeset) do
    # Only generate slug if it doesn't exist yet (for new records)
    # This keeps the slug stable even when the name is updated
    existing_slug = get_field(changeset, :slug)

    if existing_slug do
      changeset
    else
      case get_change(changeset, :name) do
        nil ->
          changeset

        name ->
          workspace_id = get_field(changeset, :id)
          slug = SlugGenerator.generate(name, &MembershipRepository.slug_exists?/2, workspace_id)
          put_change(changeset, :slug, slug)
      end
    end
  end
end
