defmodule Jarga.Agents.ChatMessage do
  @moduledoc """
  Schema for chat messages within a session.

  Each message represents a single turn in a conversation, either from
  the user or the AI assistant. Messages can optionally reference document
  chunks that were used as context.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @valid_roles ~w(user assistant)

  schema "chat_messages" do
    field(:role, :string)
    field(:content, :string)
    field(:context_chunks, {:array, :binary_id}, default: [])

    belongs_to(:chat_session, Jarga.Agents.ChatSession)

    timestamps(type: :utc_datetime)
  end

  @doc """
  Changeset for creating a new chat message.

  Required fields:
  - chat_session_id
  - role (must be "user" or "assistant")
  - content

  Optional fields:
  - context_chunks (array of document chunk IDs used as context)
  """
  def changeset(message, attrs) do
    message
    |> cast(attrs, [:chat_session_id, :role, :content, :context_chunks])
    |> validate_required([:chat_session_id, :role, :content])
    |> validate_inclusion(:role, @valid_roles)
    |> trim_content()
    |> validate_required([:content])
    |> foreign_key_constraint(:chat_session_id)
  end

  defp trim_content(changeset) do
    case get_change(changeset, :content) do
      nil ->
        changeset

      content when is_binary(content) ->
        trimmed = String.trim(content)

        if trimmed == "" do
          put_change(changeset, :content, nil)
        else
          put_change(changeset, :content, trimmed)
        end

      _ ->
        changeset
    end
  end
end
