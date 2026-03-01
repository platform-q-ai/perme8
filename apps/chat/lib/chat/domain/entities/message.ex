defmodule Chat.Domain.Entities.Message do
  @moduledoc """
  Pure domain entity for chat messages.

  For database persistence, see Chat.Infrastructure.Schemas.MessageSchema.
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

  def new(attrs) do
    struct(__MODULE__, attrs)
  end

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
