defmodule Jarga.Documents.Notes.Infrastructure.Schemas.NoteSchema do
  @moduledoc """
  Ecto schema for notes.
  This is the infrastructure representation that handles database persistence.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: false}
  @foreign_key_type :binary_id

  schema "notes" do
    field(:note_content, :map)
    field(:yjs_state, :binary)

    belongs_to(:user, Jarga.Accounts.Infrastructure.Schemas.UserSchema)
    belongs_to(:workspace, Jarga.Workspaces.Domain.Entities.Workspace, type: Ecto.UUID)
    belongs_to(:project, Jarga.Projects.Infrastructure.Schemas.ProjectSchema, type: Ecto.UUID)

    timestamps(type: :utc_datetime)
  end

  @doc """
  Changeset for creating and updating notes.
  Accepts either a schema struct or a domain entity (which will be converted).
  """
  def changeset(note, attrs) do
    schema = to_schema(note)

    schema
    |> cast(attrs, [:id, :user_id, :workspace_id, :project_id, :note_content, :yjs_state])
    |> validate_required([:id, :user_id, :workspace_id])
    |> foreign_key_constraint(:user_id)
    |> foreign_key_constraint(:workspace_id)
    |> foreign_key_constraint(:project_id)
  end

  @doc """
  Converts a domain entity to a schema struct.
  If already a schema, returns it unchanged.
  """
  def to_schema(%__MODULE__{} = schema), do: schema

  def to_schema(%{__struct__: _} = domain_entity) do
    %__MODULE__{
      id: domain_entity.id,
      note_content: domain_entity.note_content,
      yjs_state: domain_entity.yjs_state,
      user_id: domain_entity.user_id,
      workspace_id: domain_entity.workspace_id,
      project_id: domain_entity.project_id,
      inserted_at: domain_entity.inserted_at,
      updated_at: domain_entity.updated_at
    }
  end
end
