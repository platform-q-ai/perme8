defmodule Jarga.Chat.Domain.Entities.Message do
  @moduledoc """
  Pure domain entity for chat messages.

  This is a value object representing a chat message in the business domain.
  It contains no infrastructure dependencies (no Ecto, no database concerns).

  Each message represents a single turn in a conversation, either from
  the user or the AI assistant. Messages can optionally reference document
  chunks that were used as context.

  For database persistence, see Jarga.Chat.Infrastructure.Schemas.MessageSchema.
  """

  @type t :: %__MODULE__{
          id: String.t() | nil,
          chat_session_id: String.t(),
          role: String.t(),
          content: String.t(),
          context_chunks: list(String.t()),
          inserted_at: DateTime.t() | nil,
          updated_at: DateTime.t() | nil
        }

  defstruct [
    :id,
    :chat_session_id,
    :role,
    :content,
    :inserted_at,
    :updated_at,
    context_chunks: []
  ]

  @doc """
  Creates a new Message domain entity from attributes.

  ## Examples

      iex> Message.new(%{
      ...>   chat_session_id: "session-123",
      ...>   role: "user",
      ...>   content: "Hello!"
      ...> })
      %Message{chat_session_id: "session-123", role: "user", content: "Hello!"}
  """
  def new(attrs) do
    struct(__MODULE__, attrs)
  end

  @doc """
  Converts an infrastructure schema to a domain entity.

  ## Examples

      iex> Message.from_schema(message_schema)
      %Message{id: "...", role: "user", content: "..."}
  """
  def from_schema(%{__struct__: _} = schema) do
    %__MODULE__{
      id: schema.id,
      chat_session_id: schema.chat_session_id,
      role: schema.role,
      content: schema.content,
      context_chunks: schema.context_chunks || [],
      inserted_at: schema.inserted_at,
      updated_at: schema.updated_at
    }
  end
end
