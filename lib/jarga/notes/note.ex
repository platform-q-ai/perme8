defmodule Jarga.Notes.Note do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: false}
  @foreign_key_type :binary_id

  schema "notes" do
    field(:note_content, :map)
    field(:yjs_state, :binary)

    belongs_to(:user, Jarga.Accounts.User)
    belongs_to(:workspace, Jarga.Workspaces.Workspace, type: Ecto.UUID)
    belongs_to(:project, Jarga.Projects.Project, type: Ecto.UUID)

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(note, attrs) do
    note
    |> cast(attrs, [:id, :user_id, :workspace_id, :project_id, :note_content, :yjs_state])
    |> validate_required([:id, :user_id, :workspace_id])
    |> foreign_key_constraint(:user_id)
    |> foreign_key_constraint(:workspace_id)
    |> foreign_key_constraint(:project_id)
  end
end
