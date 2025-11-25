defmodule Jarga.Documents.Domain.Entities.Document do
  @moduledoc """
  Pure domain entity for documents.

  This is a value object representing a document in the business domain.
  It contains no infrastructure dependencies (no Ecto, no database concerns).

  For database persistence, see Jarga.Documents.Infrastructure.Schemas.DocumentSchema.
  """

  @type t :: %__MODULE__{
          id: String.t() | nil,
          title: String.t(),
          slug: String.t(),
          is_public: boolean(),
          is_pinned: boolean(),
          user_id: String.t(),
          workspace_id: String.t(),
          project_id: String.t() | nil,
          created_by: String.t(),
          document_components: list(any()),
          inserted_at: DateTime.t() | nil,
          updated_at: DateTime.t() | nil
        }

  defstruct [
    :id,
    :title,
    :slug,
    :user_id,
    :workspace_id,
    :project_id,
    :created_by,
    :inserted_at,
    :updated_at,
    is_public: false,
    is_pinned: false,
    document_components: []
  ]

  @doc """
  Creates a new Document domain entity from attributes.
  """
  def new(attrs) do
    struct(__MODULE__, attrs)
  end

  @doc """
  Converts an infrastructure schema to a domain entity.
  Also converts nested document_components to domain entities.
  """
  def from_schema(%{__struct__: _} = schema) do
    alias Jarga.Documents.Domain.Entities.DocumentComponent

    components =
      case schema.document_components do
        nil -> []
        %Ecto.Association.NotLoaded{} -> []
        components -> Enum.map(components, &DocumentComponent.from_schema/1)
      end

    %__MODULE__{
      id: schema.id,
      title: schema.title,
      slug: schema.slug,
      is_public: schema.is_public,
      is_pinned: schema.is_pinned,
      user_id: schema.user_id,
      workspace_id: schema.workspace_id,
      project_id: schema.project_id,
      created_by: schema.created_by,
      document_components: components,
      inserted_at: schema.inserted_at,
      updated_at: schema.updated_at
    }
  end
end
