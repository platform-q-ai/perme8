defmodule Jarga.Pages.Page do
  use Ecto.Schema
  import Ecto.Changeset

  alias Jarga.Pages.Domain.SlugGenerator
  alias Jarga.Pages.Infrastructure.PageRepository

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "pages" do
    field :title, :string
    field :slug, :string
    field :is_public, :boolean, default: false
    field :is_pinned, :boolean, default: false

    belongs_to :user, Jarga.Accounts.User
    belongs_to :workspace, Jarga.Workspaces.Workspace, type: Ecto.UUID
    belongs_to :project, Jarga.Projects.Project, type: Ecto.UUID
    belongs_to :created_by_user, Jarga.Accounts.User, foreign_key: :created_by

    # Polymorphic components (notes, task lists, sheets, etc.)
    has_many :page_components, Jarga.Pages.PageComponent, preload_order: [asc: :position]

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(page, attrs) do
    page
    |> cast(attrs, [:title, :user_id, :workspace_id, :project_id, :created_by, :is_public, :is_pinned])
    |> validate_required([:title, :user_id, :workspace_id, :created_by])
    |> validate_length(:title, min: 1)
    |> generate_slug()
    |> validate_required([:slug])
    |> unique_constraint(:slug, name: :pages_workspace_id_slug_index)
    |> foreign_key_constraint(:user_id)
    |> foreign_key_constraint(:workspace_id)
    |> foreign_key_constraint(:project_id)
    |> foreign_key_constraint(:created_by)
  end

  defp generate_slug(changeset) do
    # Only generate slug if it doesn't exist yet (for new records)
    # This keeps the slug stable even when the title is updated
    existing_slug = get_field(changeset, :slug)

    if existing_slug do
      changeset
    else
      case get_change(changeset, :title) do
        nil ->
          changeset

        title ->
          page_id = get_field(changeset, :id)
          workspace_id = get_field(changeset, :workspace_id)
          slug = SlugGenerator.generate(title, workspace_id, &PageRepository.slug_exists_in_workspace?/3, page_id)
          put_change(changeset, :slug, slug)
      end
    end
  end
end
