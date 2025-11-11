defmodule Jarga.Agents.ChatSession do
  @moduledoc """
  Schema for chat sessions.

  A chat session represents a conversation thread with the AI assistant.
  Sessions can be scoped to a workspace or project and belong to a user.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "chat_sessions" do
    field(:title, :string)

    belongs_to(:user, Jarga.Accounts.User)
    belongs_to(:workspace, Jarga.Workspaces.Workspace)
    belongs_to(:project, Jarga.Projects.Project)

    has_many(:messages, Jarga.Agents.ChatMessage)

    timestamps(type: :utc_datetime)
  end

  @doc """
  Changeset for creating a new chat session.

  Required fields:
  - user_id

  Optional fields:
  - title
  - workspace_id
  - project_id
  """
  def changeset(session, attrs) do
    session
    |> cast(attrs, [:title, :user_id, :workspace_id, :project_id])
    |> validate_required([:user_id])
    |> trim_title()
    |> validate_length(:title, max: 255)
    |> foreign_key_constraint(:user_id)
    |> foreign_key_constraint(:workspace_id)
    |> foreign_key_constraint(:project_id)
  end

  @doc """
  Changeset for updating the title of an existing session.
  """
  def title_changeset(session, attrs) do
    session
    |> cast(attrs, [:title])
    |> trim_title()
    |> validate_length(:title, max: 255)
  end

  defp trim_title(changeset) do
    case get_change(changeset, :title) do
      nil -> changeset
      title when is_binary(title) -> put_change(changeset, :title, String.trim(title))
      _ -> changeset
    end
  end
end
