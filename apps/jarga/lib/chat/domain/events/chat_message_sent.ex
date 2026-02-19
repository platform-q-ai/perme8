defmodule Jarga.Chat.Domain.Events.ChatMessageSent do
  @moduledoc """
  Domain event emitted when a chat message is sent.
  """

  use Perme8.Events.DomainEvent,
    aggregate_type: "chat_session",
    fields: [message_id: nil, session_id: nil, user_id: nil, role: nil],
    required: [:message_id, :session_id, :user_id, :role]
end
