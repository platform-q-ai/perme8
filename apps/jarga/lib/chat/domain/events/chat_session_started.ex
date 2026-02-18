defmodule Jarga.Chat.Domain.Events.ChatSessionStarted do
  @moduledoc """
  Domain event emitted when a chat session is started.
  """

  use Perme8.Events.DomainEvent,
    aggregate_type: "chat_session",
    fields: [session_id: nil, user_id: nil, agent_id: nil],
    required: [:session_id, :user_id]
end
