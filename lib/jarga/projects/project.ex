defmodule Jarga.Projects.Project do
  @moduledoc """
  Schema for projects that organize pages within workspaces.
  """

  use Ecto.Schema
  import Ecto.Changeset

  alias Jarga.Projects.Domain.SlugGenerator
  alias Jarga.Projects.Infrastructure.ProjectRepository

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "projects" do
    field(:name, :string)
    field(:slug, :string)
    field(:description, :string)
    field(:color, :string)
    field(:is_default, :boolean, default: false)
    field(:is_archived, :boolean, default: false)

    belongs_to(:user, Jarga.Accounts.User)
    belongs_to(:workspace, Jarga.Workspaces.Workspace)

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(project, attrs) do
    project
    |> cast(attrs, [
      :name,
      :description,
      :color,
      :is_default,
      :is_archived,
      :user_id,
      :workspace_id
    ])
    |> validate_required([:name, :user_id, :workspace_id])
    |> validate_length(:name, min: 1)
    |> generate_slug()
    |> validate_required([:slug])
    |> unique_constraint(:slug, name: :projects_workspace_id_slug_index)
    |> foreign_key_constraint(:user_id)
    |> foreign_key_constraint(:workspace_id)
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
          project_id = get_field(changeset, :id)
          workspace_id = get_field(changeset, :workspace_id)

          slug =
            SlugGenerator.generate(
              name,
              workspace_id,
              &ProjectRepository.slug_exists_in_workspace?/3,
              project_id
            )

          put_change(changeset, :slug, slug)
      end
    end
  end
end
