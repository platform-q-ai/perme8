defmodule Jarga.Documents.Infrastructure.Schemas.DocumentSchema do
  @moduledoc """
  Ecto schema for documents.
  This is the infrastructure representation that handles database persistence.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "documents" do
    field(:title, :string)
    field(:slug, :string)
    field(:is_public, :boolean, default: false)
    field(:is_pinned, :boolean, default: false)

    belongs_to(:user, Jarga.Accounts.Infrastructure.Schemas.UserSchema)
    belongs_to(:workspace, Jarga.Workspaces.Domain.Entities.Workspace, type: Ecto.UUID)
    belongs_to(:project, Jarga.Projects.Infrastructure.Schemas.ProjectSchema, type: Ecto.UUID)

    belongs_to(:created_by_user, Jarga.Accounts.Infrastructure.Schemas.UserSchema,
      foreign_key: :created_by
    )

    # Polymorphic components (notes, task lists, sheets, etc.)
    has_many(:document_components, Jarga.Documents.Infrastructure.Schemas.DocumentComponentSchema,
      foreign_key: :document_id,
      preload_order: [asc: :position]
    )

    timestamps(type: :utc_datetime)
  end

  @doc """
  Changeset for creating and updating documents.
  Accepts either a schema struct or a domain entity (which will be converted).
  """
  def changeset(document, attrs) do
    schema = to_schema(document)

    schema
    |> cast(attrs, [
      :title,
      :slug,
      :user_id,
      :workspace_id,
      :project_id,
      :created_by,
      :is_public,
      :is_pinned
    ])
    |> validate_required([:title, :slug, :user_id, :workspace_id, :created_by])
    |> validate_length(:title, min: 1)
    |> unique_constraint(:slug, name: :documents_workspace_id_slug_index)
    |> foreign_key_constraint(:user_id, name: :pages_user_id_fkey)
    |> foreign_key_constraint(:workspace_id, name: :pages_workspace_id_fkey)
    |> foreign_key_constraint(:project_id, name: :pages_project_id_fkey)
    |> foreign_key_constraint(:created_by, name: :pages_created_by_fkey)
  end

  @doc """
  Converts a domain entity to a schema struct.
  If already a schema, returns it unchanged.
  """
  def to_schema(%__MODULE__{} = schema), do: schema

  def to_schema(%{__struct__: _} = domain_entity) do
    %__MODULE__{
      id: domain_entity.id,
      title: domain_entity.title,
      slug: domain_entity.slug,
      is_public: domain_entity.is_public,
      is_pinned: domain_entity.is_pinned,
      user_id: domain_entity.user_id,
      workspace_id: domain_entity.workspace_id,
      project_id: domain_entity.project_id,
      created_by: domain_entity.created_by,
      inserted_at: domain_entity.inserted_at,
      updated_at: domain_entity.updated_at
    }
  end
end
