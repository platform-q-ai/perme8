defmodule Chat.Infrastructure.Schemas.SessionSchema do
  @moduledoc """
  Ecto schema for chat sessions persistence.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "chat_sessions" do
    field(:title, :string)
    field(:user_id, :binary_id)
    field(:workspace_id, :binary_id)
    field(:project_id, :binary_id)

    has_many(:messages, Chat.Infrastructure.Schemas.MessageSchema, foreign_key: :chat_session_id)

    timestamps(type: :utc_datetime)
  end

  def changeset(session, attrs) do
    session
    |> cast(attrs, [:title, :user_id, :workspace_id, :project_id])
    |> validate_required([:user_id])
    |> trim_title()
    |> validate_length(:title, max: 255)
  end

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
