defmodule Jarga.Chat.Domain.Events.ChatSessionDeleted do
  @moduledoc """
  Domain event emitted when a chat session is deleted.
  """

  use Perme8.Events.DomainEvent,
    aggregate_type: "chat_session",
    fields: [session_id: nil, user_id: nil],
    required: [:session_id, :user_id]
end
