defmodule Jarga.Chat.Domain.Entities.Session do
  @moduledoc """
  Pure domain entity for chat sessions.

  This is a value object representing a chat session in the business domain.
  It contains no infrastructure dependencies (no Ecto, no database concerns).

  A chat session represents a conversation thread with the AI assistant.
  Sessions can be scoped to a workspace or project and belong to a user.

  For database persistence, see Jarga.Chat.Infrastructure.Schemas.SessionSchema.
  """

  @type t :: %__MODULE__{
          id: String.t() | nil,
          title: String.t() | nil,
          user_id: String.t(),
          workspace_id: String.t() | nil,
          project_id: String.t() | nil,
          messages: list(any()),
          inserted_at: DateTime.t() | nil,
          updated_at: DateTime.t() | nil
        }

  defstruct [
    :id,
    :title,
    :user_id,
    :workspace_id,
    :project_id,
    :inserted_at,
    :updated_at,
    messages: []
  ]

  @doc """
  Creates a new Session domain entity from attributes.

  ## Examples

      iex> Session.new(%{user_id: "user-123", title: "My Chat"})
      %Session{user_id: "user-123", title: "My Chat", messages: []}
  """
  def new(attrs) do
    struct(__MODULE__, attrs)
  end

  @doc """
  Converts an infrastructure schema to a domain entity.
  Also converts nested messages to domain entities.

  ## Examples

      iex> Session.from_schema(session_schema)
      %Session{id: "...", messages: [...]}
  """
  def from_schema(%{__struct__: _} = schema) do
    alias Jarga.Chat.Domain.Entities.Message

    messages =
      case schema.messages do
        nil -> []
        %Ecto.Association.NotLoaded{} -> []
        messages -> Enum.map(messages, &Message.from_schema/1)
      end

    %__MODULE__{
      id: schema.id,
      title: schema.title,
      user_id: schema.user_id,
      workspace_id: schema.workspace_id,
      project_id: schema.project_id,
      messages: messages,
      inserted_at: schema.inserted_at,
      updated_at: schema.updated_at
    }
  end
end
